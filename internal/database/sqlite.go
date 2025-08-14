package database

import (
	"database/sql"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	_ "modernc.org/sqlite"
)

type SQLiteDB struct {
	db   *sql.DB
	path string
}

// NewSQLiteDB creates a new SQLite database connection
func NewSQLiteDB(dbPath string) (*SQLiteDB, error) {
	// Ensure directory exists
	dir := filepath.Dir(dbPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create database directory: %v", err)
	}

	// Open database connection
	db, err := sql.Open("sqlite", dbPath+"?_foreign_keys=on&_journal_mode=WAL")
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %v", err)
	}

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %v", err)
	}

	sqliteDB := &SQLiteDB{
		db:   db,
		path: dbPath,
	}

	// Run migrations
	if err := sqliteDB.runMigrations(); err != nil {
		return nil, fmt.Errorf("failed to run migrations: %v", err)
	}

	log.Printf("SQLite database initialized at: %s", dbPath)
	return sqliteDB, nil
}

// GetDB returns the underlying sql.DB instance
func (s *SQLiteDB) GetDB() *sql.DB {
	return s.db
}

// Close closes the database connection
func (s *SQLiteDB) Close() error {
	if s.db != nil {
		return s.db.Close()
	}
	return nil
}

// runMigrations executes all migration files
func (s *SQLiteDB) runMigrations() error {
	// Create migrations table if it doesn't exist
	createMigrationsTable := `
	CREATE TABLE IF NOT EXISTS migrations (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		filename VARCHAR(255) NOT NULL UNIQUE,
		executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);`

	if _, err := s.db.Exec(createMigrationsTable); err != nil {
		return fmt.Errorf("failed to create migrations table: %v", err)
	}

	// Get migration files directory
	migrationsDir := "./internal/database/migrations"
	
	// Check if migrations directory exists
	if _, err := os.Stat(migrationsDir); os.IsNotExist(err) {
		log.Printf("Migrations directory not found: %s", migrationsDir)
		return nil
	}

	// Read migration files
	files, err := ioutil.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("failed to read migrations directory: %v", err)
	}

	for _, file := range files {
		if !strings.HasSuffix(file.Name(), ".sql") {
			continue
		}

		// Check if migration already executed
		var count int
		err := s.db.QueryRow("SELECT COUNT(*) FROM migrations WHERE filename = ?", file.Name()).Scan(&count)
		if err != nil {
			return fmt.Errorf("failed to check migration status: %v", err)
		}

		if count > 0 {
			continue // Migration already executed
		}

		// Read and execute migration
		migrationPath := filepath.Join(migrationsDir, file.Name())
		content, err := ioutil.ReadFile(migrationPath)
		if err != nil {
			return fmt.Errorf("failed to read migration file %s: %v", file.Name(), err)
		}

		// Execute migration
		if _, err := s.db.Exec(string(content)); err != nil {
			return fmt.Errorf("failed to execute migration %s: %v", file.Name(), err)
		}

		// Record migration as executed
		if _, err := s.db.Exec("INSERT INTO migrations (filename) VALUES (?)", file.Name()); err != nil {
			return fmt.Errorf("failed to record migration %s: %v", file.Name(), err)
		}

		log.Printf("Executed migration: %s", file.Name())
	}

	return nil
}

// HealthCheck performs a basic health check on the database
func (s *SQLiteDB) HealthCheck() error {
	var result int
	err := s.db.QueryRow("SELECT 1").Scan(&result)
	if err != nil {
		return fmt.Errorf("database health check failed: %v", err)
	}
	return nil
}

// GetStats returns basic database statistics
func (s *SQLiteDB) GetStats() (map[string]interface{}, error) {
	stats := make(map[string]interface{})

	// Get database size
	if info, err := os.Stat(s.path); err == nil {
		stats["size_bytes"] = info.Size()
	}

	// Get table counts
	tables := []string{"prediction_tracking", "market_calendar", "daily_execution_log"}
	for _, table := range tables {
		var count int
		query := fmt.Sprintf("SELECT COUNT(*) FROM %s", table)
		if err := s.db.QueryRow(query).Scan(&count); err == nil {
			stats[table+"_count"] = count
		}
	}

	return stats, nil
}
