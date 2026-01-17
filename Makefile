# ============================================================================
# Reminder2Cal - macOS Application Build System (xcodebuild)
# ============================================================================

# Version from Xcode project settings
VERSION := $(shell grep 'MARKETING_VERSION' Reminder2Cal.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //' | tr -d '; ')
BUILD_NUMBER := $(shell grep 'CURRENT_PROJECT_VERSION' Reminder2Cal.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //' | tr -d '; ')

# Xcode Configuration
PROJECT := Reminder2Cal.xcodeproj
SCHEME := Reminder2Cal
BUILD_DIR := build
DERIVED_DATA := $(BUILD_DIR)/DerivedData
ARCHIVE_PATH := $(BUILD_DIR)/Reminder2Cal.xcarchive
EXPORT_PATH := $(BUILD_DIR)/Export

# Paths
APP_PATH := $(DERIVED_DATA)/Build/Products/Release/Reminder2Cal.app
PKG_PATH := $(EXPORT_PATH)/Reminder2Cal.pkg

# App Store Connect
TEAM_ID := MY427949GW

# Load secrets from .env.local (gitignored) if exists
-include .env.local

# xcodebuild base command
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME)

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

# ============================================================================
# Main Targets
# ============================================================================

.PHONY: all build app debug clean run archive export pkg upload release lint format install info help validate

all: build ## Build the application (default)

help: ## Show this help message
	@echo "$(BLUE)Reminder2Cal Build System (xcodebuild)$(NC)"
	@echo "Version: $(VERSION) (Build $(BUILD_NUMBER))"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

# ============================================================================
# Build Targets
# ============================================================================

build: ## Build Release (universal binary)
	@echo "$(BLUE)Building Reminder2Cal $(VERSION)...$(NC)"
	@$(XCODEBUILD) build \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-derivedDataPath $(DERIVED_DATA) \
		ONLY_ACTIVE_ARCH=NO \
		-quiet
	@echo "$(GREEN)✓ Build complete: $(APP_PATH)$(NC)"

app: build ## Alias for build

debug: ## Build Debug (active arch only, for development)
	@echo "$(BLUE)Building Debug...$(NC)"
	@$(XCODEBUILD) build \
		-configuration Debug \
		-destination 'generic/platform=macOS' \
		-derivedDataPath $(DERIVED_DATA) \
		-quiet
	@echo "$(GREEN)✓ Debug build complete$(NC)"

clean: ## Clean all build artifacts
	@echo "$(YELLOW)Cleaning...$(NC)"
	@$(XCODEBUILD) clean -quiet 2>/dev/null || true
	@rm -rf $(BUILD_DIR) *.pkg *.app .build
	@echo "$(GREEN)✓ Clean complete$(NC)"

run: build ## Build and run the application
	@echo "$(BLUE)Starting Reminder2Cal...$(NC)"
	@open "$(APP_PATH)"

run-debug: debug ## Build debug and run
	@echo "$(BLUE)Starting Reminder2Cal (Debug)...$(NC)"
	@open "$(DERIVED_DATA)/Build/Products/Debug/Reminder2Cal.app"

install: build ## Install to /Applications
	@echo "$(BLUE)Installing to /Applications...$(NC)"
	@pkill Reminder2Cal 2>/dev/null || true
	@rm -rf /Applications/Reminder2Cal.app
	@cp -R "$(APP_PATH)" /Applications/
	@echo "$(GREEN)✓ Installed to /Applications/Reminder2Cal.app$(NC)"

# ============================================================================
# App Store Distribution
# ============================================================================

archive: ## Create archive for App Store
	@echo "$(BLUE)Creating archive...$(NC)"
	@$(XCODEBUILD) archive \
		-archivePath $(ARCHIVE_PATH) \
		-configuration Release \
		-destination 'generic/platform=macOS' \
		-allowProvisioningUpdates \
		ONLY_ACTIVE_ARCH=NO
	@echo "$(GREEN)✓ Archive created: $(ARCHIVE_PATH)$(NC)"

export: archive ## Export signed .pkg from archive
	@echo "$(BLUE)Exporting for App Store...$(NC)"
	@xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist Configuration/ExportOptions.plist \
		-allowProvisioningUpdates
	@echo "$(GREEN)✓ Package created: $(PKG_PATH)$(NC)"

pkg: export ## Alias for export

upload: export ## Upload to App Store Connect (requires .env.local)
	@if [ -z "$(API_KEY)" ] || [ -z "$(API_ISSUER)" ]; then \
		echo "$(RED)Error: API_KEY and API_ISSUER not found$(NC)"; \
		echo "Create .env.local with:"; \
		echo "  API_KEY = your-key-id"; \
		echo "  API_ISSUER = your-issuer-id"; \
		echo "Get keys at: https://appstoreconnect.apple.com/access/integrations/api"; \
		exit 1; \
	fi
	@echo "$(BLUE)Uploading to App Store Connect...$(NC)"
	@xcrun altool --upload-app \
		-f "$(PKG_PATH)" \
		--apiKey "$(API_KEY)" \
		--apiIssuer "$(API_ISSUER)" \
		-t macos
	@echo "$(GREEN)✓ Upload complete$(NC)"

release: clean upload ## Full release: clean → archive → export → upload
	@echo ""
	@echo "$(GREEN)✓ Release $(VERSION) uploaded to App Store Connect$(NC)"
	@echo "$(BLUE)Next: Go to App Store Connect to submit for review$(NC)"

# ============================================================================
# Code Quality
# ============================================================================

lint: ## Check code style with swift-format
	@echo "$(BLUE)Checking code style...$(NC)"
	@swift run --package-path . swift-format lint --configuration .swift-format --recursive Sources

format: ## Format code with swift-format
	@echo "$(BLUE)Formatting code...$(NC)"
	@swift run --package-path . swift-format format --configuration .swift-format --in-place --recursive Sources
	@echo "$(GREEN)✓ Code formatted$(NC)"

# ============================================================================
# Info & Validation
# ============================================================================

info: ## Show build information
	@echo "$(BLUE)Build Information:$(NC)"
	@echo "  Version:        $(VERSION)"
	@echo "  Build Number:   $(BUILD_NUMBER)"
	@echo "  Team ID:        $(TEAM_ID)"
	@echo "  Bundle ID:      com.marcusgrando.Reminder2Cal"
	@echo "  Xcode:          $(shell xcodebuild -version | head -1)"
	@echo "  App Path:       $(APP_PATH)"
	@echo "  Archive Path:   $(ARCHIVE_PATH)"
	@echo "  Package Path:   $(PKG_PATH)"
	@echo ""
	@if [ -n "$(API_KEY)" ]; then \
		echo "  $(GREEN)API Key:        Configured$(NC)"; \
	else \
		echo "  $(YELLOW)API Key:        Not configured (see .env.local.example)$(NC)"; \
	fi

validate: build ## Validate the built app
	@echo "$(BLUE)Validating...$(NC)"
	@test -d "$(APP_PATH)" || { echo "$(RED)✗ App not found$(NC)"; exit 1; }
	@codesign --verify --verbose=1 "$(APP_PATH)" 2>&1 | head -1
	@echo "$(GREEN)✓ App is valid$(NC)"

# ============================================================================

.DEFAULT_GOAL := all
