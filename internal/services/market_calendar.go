package services

import (
	"database/sql"
	"fmt"
	"log"
	"time"

	"stock-prediction-us/internal/models"
)

type MarketCalendarService struct {
	db *sql.DB
}

// NewMarketCalendarService creates a new market calendar service
func NewMarketCalendarService(db *sql.DB) *MarketCalendarService {
	return &MarketCalendarService{
		db: db,
	}
}

// IsMarketOpen checks if the US stock market was open on a given date
func (s *MarketCalendarService) IsMarketOpen(date time.Time) (bool, error) {
	// Normalize date to remove time component
	dateOnly := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.UTC)
	
	// Check if it's a weekend
	weekday := dateOnly.Weekday()
	if weekday == time.Saturday || weekday == time.Sunday {
		return false, nil
	}
	
	// Check database for specific holiday information
	var isOpen bool
	var found bool
	
	query := `SELECT is_market_open FROM market_calendar WHERE date = ? AND market_type = 'US'`
	err := s.db.QueryRow(query, dateOnly.Format("2006-01-02")).Scan(&isOpen)
	
	if err == sql.ErrNoRows {
		// No specific entry found, assume market is open on weekdays
		found = false
		isOpen = true
	} else if err != nil {
		return false, fmt.Errorf("failed to query market calendar: %v", err)
	} else {
		found = true
	}
	
	// If no specific entry found and it's a weekday, assume market is open
	if !found && weekday >= time.Monday && weekday <= time.Friday {
		return true, nil
	}
	
	return isOpen, nil
}

// WasMarketOpenYesterday checks if the market was open on the previous trading day
func (s *MarketCalendarService) WasMarketOpenYesterday() (bool, time.Time, error) {
	now := time.Now()
	yesterday := now.AddDate(0, 0, -1)
	
	isOpen, err := s.IsMarketOpen(yesterday)
	if err != nil {
		return false, yesterday, err
	}
	
	return isOpen, yesterday, nil
}

// GetLastTradingDay returns the most recent trading day
func (s *MarketCalendarService) GetLastTradingDay() (time.Time, error) {
	now := time.Now()
	
	// Look back up to 10 days to find the last trading day
	for i := 1; i <= 10; i++ {
		checkDate := now.AddDate(0, 0, -i)
		isOpen, err := s.IsMarketOpen(checkDate)
		if err != nil {
			return time.Time{}, err
		}
		
		if isOpen {
			return checkDate, nil
		}
	}
	
	return time.Time{}, fmt.Errorf("no trading day found in the last 10 days")
}

// AddHoliday adds a new holiday to the market calendar
func (s *MarketCalendarService) AddHoliday(date time.Time, holidayName string) error {
	dateOnly := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.UTC)
	
	query := `
		INSERT OR REPLACE INTO market_calendar (date, is_market_open, holiday_name, market_type)
		VALUES (?, ?, ?, 'US')
	`
	
	_, err := s.db.Exec(query, dateOnly.Format("2006-01-02"), false, holidayName)
	if err != nil {
		return fmt.Errorf("failed to add holiday: %v", err)
	}
	
	log.Printf("Added holiday to market calendar: %s on %s", holidayName, dateOnly.Format("2006-01-02"))
	return nil
}

// GetMarketCalendar returns market calendar entries for a date range
func (s *MarketCalendarService) GetMarketCalendar(startDate, endDate time.Time) ([]models.MarketCalendar, error) {
	query := `
		SELECT id, date, is_market_open, holiday_name, market_type, created_at
		FROM market_calendar
		WHERE date >= ? AND date <= ? AND market_type = 'US'
		ORDER BY date
	`
	
	rows, err := s.db.Query(query, startDate.Format("2006-01-02"), endDate.Format("2006-01-02"))
	if err != nil {
		return nil, fmt.Errorf("failed to query market calendar: %v", err)
	}
	defer rows.Close()
	
	var calendars []models.MarketCalendar
	for rows.Next() {
		var cal models.MarketCalendar
		var dateStr string
		var holidayName sql.NullString
		
		err := rows.Scan(&cal.ID, &dateStr, &cal.IsMarketOpen, &holidayName, &cal.MarketType, &cal.CreatedAt)
		if err != nil {
			return nil, fmt.Errorf("failed to scan market calendar row: %v", err)
		}
		
		// Try parsing as date first, then as timestamp if that fails
		cal.Date, err = time.Parse("2006-01-02", dateStr)
		if err != nil {
			// Try parsing as timestamp format
			cal.Date, err = time.Parse("2006-01-02T15:04:05Z", dateStr)
			if err != nil {
				// Try parsing as timestamp with milliseconds
				cal.Date, err = time.Parse("2006-01-02T15:04:05.000Z", dateStr)
				if err != nil {
					return nil, fmt.Errorf("failed to parse date '%s': %v", dateStr, err)
				}
			}
		}
		
		if holidayName.Valid {
			cal.HolidayName = &holidayName.String
		}
		
		calendars = append(calendars, cal)
	}
	
	return calendars, nil
}

// PopulateUSHolidays populates the database with US market holidays for a given year
func (s *MarketCalendarService) PopulateUSHolidays(year int) error {
	holidays := s.getUSMarketHolidays(year)
	
	for date, name := range holidays {
		if err := s.AddHoliday(date, name); err != nil {
			log.Printf("Warning: Failed to add holiday %s: %v", name, err)
		}
	}
	
	log.Printf("Populated US market holidays for year %d", year)
	return nil
}

// getUSMarketHolidays returns a map of US market holidays for a given year
func (s *MarketCalendarService) getUSMarketHolidays(year int) map[time.Time]string {
	holidays := make(map[time.Time]string)
	
	// Fixed date holidays
	holidays[time.Date(year, 1, 1, 0, 0, 0, 0, time.UTC)] = "New Year's Day"
	holidays[time.Date(year, 7, 4, 0, 0, 0, 0, time.UTC)] = "Independence Day"
	holidays[time.Date(year, 12, 25, 0, 0, 0, 0, time.UTC)] = "Christmas Day"
	
	// Juneteenth (June 19th, federal holiday since 2021)
	if year >= 2021 {
		holidays[time.Date(year, 6, 19, 0, 0, 0, 0, time.UTC)] = "Juneteenth"
	}
	
	// Variable date holidays
	holidays[s.getNthWeekdayOfMonth(year, 1, time.Monday, 3)] = "Martin Luther King Jr. Day"
	holidays[s.getNthWeekdayOfMonth(year, 2, time.Monday, 3)] = "Presidents' Day"
	holidays[s.getLastWeekdayOfMonth(year, 5, time.Monday)] = "Memorial Day"
	holidays[s.getNthWeekdayOfMonth(year, 9, time.Monday, 1)] = "Labor Day"
	holidays[s.getNthWeekdayOfMonth(year, 11, time.Thursday, 4)] = "Thanksgiving Day"
	
	// Good Friday (Friday before Easter)
	easter := s.getEasterDate(year)
	goodFriday := easter.AddDate(0, 0, -2)
	holidays[goodFriday] = "Good Friday"
	
	// Handle holidays that fall on weekends (observed on Friday or Monday)
	adjustedHolidays := make(map[time.Time]string)
	for date, name := range holidays {
		adjustedDate := s.adjustHolidayForWeekend(date)
		adjustedHolidays[adjustedDate] = name
	}
	
	return adjustedHolidays
}

// getNthWeekdayOfMonth returns the nth occurrence of a weekday in a month
func (s *MarketCalendarService) getNthWeekdayOfMonth(year int, month time.Month, weekday time.Weekday, n int) time.Time {
	firstDay := time.Date(year, month, 1, 0, 0, 0, 0, time.UTC)
	
	// Find the first occurrence of the weekday
	daysUntilWeekday := int(weekday - firstDay.Weekday())
	if daysUntilWeekday < 0 {
		daysUntilWeekday += 7
	}
	
	firstOccurrence := firstDay.AddDate(0, 0, daysUntilWeekday)
	return firstOccurrence.AddDate(0, 0, (n-1)*7)
}

// getLastWeekdayOfMonth returns the last occurrence of a weekday in a month
func (s *MarketCalendarService) getLastWeekdayOfMonth(year int, month time.Month, weekday time.Weekday) time.Time {
	// Start from the last day of the month and work backwards
	lastDay := time.Date(year, month+1, 0, 0, 0, 0, 0, time.UTC) // Last day of the month
	
	daysBack := int(lastDay.Weekday() - weekday)
	if daysBack < 0 {
		daysBack += 7
	}
	
	return lastDay.AddDate(0, 0, -daysBack)
}

// getEasterDate calculates Easter date for a given year using the algorithm
func (s *MarketCalendarService) getEasterDate(year int) time.Time {
	// Using the algorithm for Western Easter
	a := year % 19
	b := year / 100
	c := year % 100
	d := b / 4
	e := b % 4
	f := (b + 8) / 25
	g := (b - f + 1) / 3
	h := (19*a + b - d - g + 15) % 30
	i := c / 4
	k := c % 4
	l := (32 + 2*e + 2*i - h - k) % 7
	m := (a + 11*h + 22*l) / 451
	month := (h + l - 7*m + 114) / 31
	day := ((h + l - 7*m + 114) % 31) + 1
	
	return time.Date(year, time.Month(month), day, 0, 0, 0, 0, time.UTC)
}

// adjustHolidayForWeekend adjusts holiday dates that fall on weekends
func (s *MarketCalendarService) adjustHolidayForWeekend(date time.Time) time.Time {
	switch date.Weekday() {
	case time.Saturday:
		// Observed on Friday
		return date.AddDate(0, 0, -1)
	case time.Sunday:
		// Observed on Monday
		return date.AddDate(0, 0, 1)
	default:
		return date
	}
}

// GetTradingDaysInRange returns the number of trading days in a date range
func (s *MarketCalendarService) GetTradingDaysInRange(startDate, endDate time.Time) (int, error) {
	count := 0
	current := startDate
	
	for current.Before(endDate) || current.Equal(endDate) {
		isOpen, err := s.IsMarketOpen(current)
		if err != nil {
			return 0, err
		}
		
		if isOpen {
			count++
		}
		
		current = current.AddDate(0, 0, 1)
	}
	
	return count, nil
}

// InitializeCurrentYear populates holidays for the current year if not already done
func (s *MarketCalendarService) InitializeCurrentYear() error {
	currentYear := time.Now().Year()
	
	// Check if we already have holidays for this year
	startOfYear := time.Date(currentYear, 1, 1, 0, 0, 0, 0, time.UTC)
	endOfYear := time.Date(currentYear, 12, 31, 0, 0, 0, 0, time.UTC)
	
	holidays, err := s.GetMarketCalendar(startOfYear, endOfYear)
	if err != nil {
		return err
	}
	
	// If we have fewer than 8 holidays, populate the year
	if len(holidays) < 8 {
		return s.PopulateUSHolidays(currentYear)
	}
	
	return nil
}
