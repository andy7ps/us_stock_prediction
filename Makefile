.PHONY: build run test clean docker-build docker-run docker-stop fmt lint deps help

# Variables
APP_NAME=stock-prediction-v3
DOCKER_IMAGE=stock-prediction:v3
GO_VERSION=1.23

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Development targets
deps: ## Install dependencies
	go mod download
	go mod tidy

fmt: ## Format code
	go fmt ./...
	goimports -w .

lint: ## Run linter
	golangci-lint run

build: ## Build the application
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/$(APP_NAME) .

run: ## Run the application locally
	go run main.go

test: ## Run tests
	go test -v -race -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

test-short: ## Run short tests
	go test -v -short ./...

clean: ## Clean build artifacts
	rm -rf bin/
	rm -f coverage.out coverage.html

# Docker targets
docker-build: ## Build Docker image
	docker build -t $(DOCKER_IMAGE) .

docker-run: ## Run with Docker Compose
	docker-compose up -d

docker-stop: ## Stop Docker Compose
	docker-compose down

docker-logs: ## View Docker logs
	docker-compose logs -f stock-prediction

docker-clean: ## Clean Docker resources
	docker-compose down -v
	docker rmi $(DOCKER_IMAGE) 2>/dev/null || true

docker-push: ## Push to Docker Hub (requires DOCKERHUB_USERNAME)
	@if [ -z "$(DOCKERHUB_USERNAME)" ]; then \
		echo "Error: DOCKERHUB_USERNAME not set. Usage: make docker-push DOCKERHUB_USERNAME=yourusername"; \
		exit 1; \
	fi
	./upload_to_dockerhub.sh $(DOCKERHUB_USERNAME)

docker-tag: ## Tag image for Docker Hub (requires DOCKERHUB_USERNAME)
	@if [ -z "$(DOCKERHUB_USERNAME)" ]; then \
		echo "Error: DOCKERHUB_USERNAME not set. Usage: make docker-tag DOCKERHUB_USERNAME=yourusername"; \
		exit 1; \
	fi
	docker tag $(DOCKER_IMAGE) $(DOCKERHUB_USERNAME)/$(APP_NAME):v3
	docker tag $(DOCKER_IMAGE) $(DOCKERHUB_USERNAME)/$(APP_NAME):latest

# Persistent Storage Management
storage-setup: ## Setup persistent storage directories and configuration
	./setup_persistent_storage.sh

storage-backup: ## Create backup of persistent data
	@if [ -d "persistent_data" ]; then \
		cd persistent_data && ./backup_data.sh; \
	else \
		echo "Error: Persistent storage not setup. Run 'make storage-setup' first"; \
	fi

storage-monitor: ## Monitor persistent data usage
	@if [ -d "persistent_data" ]; then \
		cd persistent_data && ./monitor_data.sh; \
	else \
		echo "Error: Persistent storage not setup. Run 'make storage-setup' first"; \
	fi

storage-cleanup: ## Cleanup old persistent data files
	@if [ -d "persistent_data" ]; then \
		cd persistent_data && ./cleanup_data.sh; \
	else \
		echo "Error: Persistent storage not setup. Run 'make storage-setup' first"; \
	fi

storage-restore: ## Restore from backup (usage: make storage-restore BACKUP=filename.tar.gz)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Usage: make storage-restore BACKUP=filename.tar.gz"; \
		echo "Available backups:"; \
		ls -la persistent_data/backups/*.tar.gz 2>/dev/null || echo "No backups found"; \
		exit 1; \
	fi
	@if [ -d "persistent_data" ]; then \
		cd persistent_data && ./restore_data.sh backups/$(BACKUP); \
	else \
		echo "Error: Persistent storage not setup. Run 'make storage-setup' first"; \
	fi

storage-test: ## Test persistent storage functionality
	@echo "🧪 Testing persistent storage..."
	@if [ ! -d "persistent_data" ]; then \
		echo "❌ Persistent storage not setup. Run 'make storage-setup' first"; \
		exit 1; \
	fi
	@echo "✅ Persistent storage directory exists"
	@if [ -w "persistent_data" ]; then \
		echo "✅ Directory is writable"; \
	else \
		echo "❌ Directory permission issue"; \
		exit 1; \
	fi
	@echo "📊 Storage usage:"
	@du -sh persistent_data 2>/dev/null || echo "Unable to calculate size"
	@echo "🎉 Persistent storage test passed!"

# Development environment
dev-setup: ## Setup development environment
	cp .env.example .env
	mkdir -p models logs
	echo "Development environment setup complete"

dev-run: deps fmt ## Run in development mode
	export LOG_LEVEL=debug && go run main.go

# Production targets
prod-build: ## Build for production
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o bin/$(APP_NAME) .

# Monitoring
monitor: ## Open monitoring dashboards
	@echo "Opening monitoring dashboards..."
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000 (admin/admin)"

# API testing
test-api: ## Test API endpoints
	@echo "Testing API endpoints..."
	curl -s http://localhost:8080/api/v1/health | jq .
	curl -s http://localhost:8080/api/v1/predict/NVDA | jq .
	curl -s http://localhost:8080/api/v1/stats | jq .

# Quick start commands
quick-start: ## Quick start with automated setup
	./quick_start.sh local

quick-start-docker: ## Quick start with Docker
	./quick_start.sh docker

quick-test: ## Quick test with full validation
	./quick_start.sh test

test-predictions: ## Interactive prediction testing
	./test_predictions.sh

test-confidence: ## Test advanced confidence calculation
	./test_advanced_confidence.sh

test-confidence-quick: ## Quick confidence test for major stocks
	@echo "Testing confidence across stock categories..."
	@echo "=== Large Cap Stable ==="
	@curl -s http://localhost:8080/api/v1/predict/MSFT | jq '{symbol, confidence, signal: .trading_signal}'
	@curl -s http://localhost:8080/api/v1/predict/GOOGL | jq '{symbol, confidence, signal: .trading_signal}'
	@echo "=== Growth/Tech ==="
	@curl -s http://localhost:8080/api/v1/predict/NVDA | jq '{symbol, confidence, signal: .trading_signal}'
	@curl -s http://localhost:8080/api/v1/predict/TSLA | jq '{symbol, confidence, signal: .trading_signal}'
	@echo "=== Volatile ==="
	@curl -s http://localhost:8080/api/v1/predict/GME | jq '{symbol, confidence, signal: .trading_signal}'
	@curl -s http://localhost:8080/api/v1/predict/AMC | jq '{symbol, confidence, signal: .trading_signal}'

test-confidence-batch: ## Batch test confidence for multiple stocks
	@for stock in AAPL MSFT GOOGL AMZN META NVDA TSLA GME AMC COIN; do \
		echo "=== $$stock ===" && \
		curl -s http://localhost:8080/api/v1/predict/$$stock | \
		jq '{symbol, confidence, change_pct: ((.predicted_price - .current_price) / .current_price * 100 | round * 100 / 100), signal: .trading_signal}' || echo "Failed to get $$stock"; \
	done

# Utility targets
check-deps: ## Check if required tools are installed
	@command -v go >/dev/null 2>&1 || { echo "Go is required but not installed"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed"; exit 1; }
	@command -v docker-compose >/dev/null 2>&1 || { echo "Docker Compose is required but not installed"; exit 1; }
	@echo "All required dependencies are installed"

install-tools: ## Install development tools
	go install golang.org/x/tools/cmd/goimports@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Git hooks
install-hooks: ## Install git hooks
	cp scripts/hooks/pre-commit .git/hooks/
	chmod +x .git/hooks/pre-commit
