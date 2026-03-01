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

# Paths
APP_PATH := $(DERIVED_DATA)/Build/Products/Release/Reminder2Cal.app
DMG_PATH := $(BUILD_DIR)/Reminder2Cal.dmg

# Signing
TEAM_ID := MY427949GW

# xcodebuild base command
XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME)

# Optional CI overrides
SIGN_IDENTITY ?=
SIGN_STYLE ?=
APP_VERSION ?=
XCODEBUILD_OVERRIDES :=
ifneq ($(SIGN_IDENTITY),)
	XCODEBUILD_OVERRIDES += CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)"
endif
ifneq ($(SIGN_STYLE),)
	XCODEBUILD_OVERRIDES += CODE_SIGN_STYLE=$(SIGN_STYLE)
endif
ifneq ($(APP_VERSION),)
	XCODEBUILD_OVERRIDES += MARKETING_VERSION=$(APP_VERSION)
	VERSION := $(APP_VERSION)
endif

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

# ============================================================================
# Main Targets
# ============================================================================

.PHONY: all build app debug clean run dmg lint format install info help validate

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
		$(XCODEBUILD_OVERRIDES) \
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
# Distribution
# ============================================================================

dmg: build ## Create .dmg for distribution
	@echo "$(BLUE)Creating DMG...$(NC)"
	@rm -f "$(DMG_PATH)"
	@hdiutil create -volname "Reminder2Cal" \
		-srcfolder "$(APP_PATH)" \
		-ov -format UDZO \
		"$(DMG_PATH)"
	@echo "$(GREEN)✓ DMG created: $(DMG_PATH)$(NC)"

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
	@echo "  DMG Path:       $(DMG_PATH)"

validate: build ## Validate the built app
	@echo "$(BLUE)Validating...$(NC)"
	@test -d "$(APP_PATH)" || { echo "$(RED)✗ App not found$(NC)"; exit 1; }
	@codesign --verify --verbose=1 "$(APP_PATH)" 2>&1 | head -1
	@echo "$(GREEN)✓ App is valid$(NC)"

# ============================================================================

.DEFAULT_GOAL := all
