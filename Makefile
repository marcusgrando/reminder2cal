# ============================================================================
# Reminder2Cal - macOS Application Build System
# ============================================================================

# Version Management (single source of truth)
VERSION := $(shell cat VERSION 2>/dev/null || echo "1.0.0")
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo "0")
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# Build Configuration
SWIFT := swift build
BUILD_CONFIG := release
SWIFT_FLAGS := --configuration $(BUILD_CONFIG) -Xswiftc -O -Xswiftc -whole-module-optimization --arch arm64 --arch x86_64
MIN_MACOS_VERSION := 14.0
SWIFT_VERSION := 5.9

# Paths (when using --arch, Swift uses apple/Products directory)
BUILD_DIR := .build/apple/Products/Release
EXECUTABLE := $(BUILD_DIR)/Reminder2Cal
APP_BUNDLE := Reminder2Cal.app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
APP_RESOURCES := $(APP_CONTENTS)/Resources

# Resource and Configuration paths
RESOURCES_DIR := Resources
CONFIG_DIR := Configuration
ENTITLEMENTS := $(CONFIG_DIR)/Entitlements.plist

# App Store Code Signing
TEAM_ID := MY427949GW
APP_IDENTITY := "3rd Party Mac Developer Application: Marcus Nestor Alves Grando ($(TEAM_ID))"
INSTALLER_IDENTITY := "3rd Party Mac Developer Installer: Marcus Nestor Alves Grando ($(TEAM_ID))"
PKG_NAME := Reminder2Cal-$(VERSION).pkg

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# ============================================================================
# Main Targets
# ============================================================================

.PHONY: all build app clean install run test help lint format pkg release validate

all: app ## Build the complete application bundle (default target)

help: ## Show this help message
	@echo "$(BLUE)Reminder2Cal Build System$(NC)"
	@echo "Version: $(VERSION) (Build $(BUILD_NUMBER))"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

# ============================================================================
# Build Targets
# ============================================================================

build: ## Build universal binary (Intel + Apple Silicon)
	@echo "$(BLUE)Building universal Reminder2Cal $(VERSION) ($(GIT_COMMIT))...$(NC)"
	$(SWIFT) $(SWIFT_FLAGS)
	@echo "$(GREEN)✓ Universal build complete$(NC)"

$(EXECUTABLE):
	@$(MAKE) -s build

app: $(EXECUTABLE) ## Create the .app bundle (signed for App Store)
	@echo "$(BLUE)Creating application bundle...$(NC)"
	@$(MAKE) -s create-bundle
	@$(MAKE) -s copy-resources
	@$(MAKE) -s update-info-plist
	@$(MAKE) -s compile-assets
	@$(MAKE) -s copy-executable
	@$(MAKE) -s sign-app
	@touch $(APP_BUNDLE)
	@echo "$(GREEN)✓ Application bundle created: $(APP_BUNDLE)$(NC)"

create-bundle:
	@mkdir -p $(APP_MACOS) $(APP_RESOURCES)

copy-resources:
	@echo "  → Copying resources..."
	@cp $(RESOURCES_DIR)/icon.icns $(APP_RESOURCES)/
	@cp $(RESOURCES_DIR)/reminder2cal.svg $(APP_RESOURCES)/
	@cp $(RESOURCES_DIR)/PrivacyInfo.xcprivacy $(APP_RESOURCES)/
	@cp $(CONFIG_DIR)/Reminder2Cal_App_Store.provisionprofile $(APP_CONTENTS)/embedded.provisionprofile
	@echo "  → Removing quarantine attributes..."
	@xattr -cr $(APP_BUNDLE) 2>/dev/null || true

update-info-plist:
	@echo "  → Updating Info.plist with version $(VERSION)..."
	@cp $(CONFIG_DIR)/Info.plist $(APP_CONTENTS)/
	@/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP_CONTENTS)/Info.plist 2>/dev/null || \
		/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(VERSION)" $(APP_CONTENTS)/Info.plist
	@/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" $(APP_CONTENTS)/Info.plist

compile-assets:
	@echo "  → Compiling asset catalog..."
	@xcrun actool \
		--output-format human-readable-text \
		--notices --warnings \
		--platform macosx \
		--minimum-deployment-target $(MIN_MACOS_VERSION) \
		--compile $(APP_RESOURCES)/ \
		$(RESOURCES_DIR)/Assets.xcassets 2>/dev/null || true

copy-executable:
	@echo "  → Copying executable..."
	@cp $(EXECUTABLE) $(APP_MACOS)/Reminder2Cal

sign-app:
	@echo "  → Code signing for App Store..."
	@codesign --force --timestamp --options runtime \
		--entitlements $(ENTITLEMENTS) \
		--sign $(APP_IDENTITY) $(APP_BUNDLE)
	@codesign --verify --verbose=2 $(APP_BUNDLE) 2>&1 | head -n 1
	@echo "$(GREEN)  ✓ Code signing complete$(NC)"

local-app: $(EXECUTABLE) ## Create .app bundle for local testing (ad-hoc signed)
	@echo "$(BLUE)Creating local application bundle...$(NC)"
	@$(MAKE) -s create-bundle
	@echo "  → Copying resources..."
	@cp $(RESOURCES_DIR)/icon.icns $(APP_RESOURCES)/
	@cp $(RESOURCES_DIR)/reminder2cal.svg $(APP_RESOURCES)/
	@cp $(RESOURCES_DIR)/PrivacyInfo.xcprivacy $(APP_RESOURCES)/
	@xattr -cr $(APP_BUNDLE) 2>/dev/null || true
	@$(MAKE) -s update-info-plist
	@$(MAKE) -s compile-assets
	@$(MAKE) -s copy-executable
	@echo "  → Code signing (ad-hoc)..."
	@codesign --force --deep --sign - $(APP_BUNDLE)
	@codesign --verify --verbose=2 $(APP_BUNDLE) 2>&1 | head -n 1
	@touch $(APP_BUNDLE)
	@echo "$(GREEN)✓ Local app bundle created: $(APP_BUNDLE)$(NC)"

# ============================================================================
# Development Targets
# ============================================================================

run: app ## Build and run the application
	@echo "$(BLUE)Starting Reminder2Cal...$(NC)"
	@open $(APP_BUNDLE)

run-debug: ## Run with debug logging
	@echo "$(BLUE)Starting Reminder2Cal with debug logging...$(NC)"
	@$(APP_MACOS)/Reminder2Cal

debug: ## Build in debug mode
	@echo "$(BLUE)Building in debug mode...$(NC)"
	@swift build --configuration debug
	@echo "$(GREEN)✓ Debug build complete$(NC)"

test: ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	@swift test

SWIFT_FORMAT := .build/release/swift-format

$(SWIFT_FORMAT):
	@echo "$(BLUE)Building swift-format...$(NC)"
	@swift build --product swift-format --configuration release
	@echo "$(GREEN)✓ swift-format built$(NC)"

lint: $(SWIFT_FORMAT) ## Check code style with swift-format
	@echo "$(BLUE)Checking code style...$(NC)"
	@$(SWIFT_FORMAT) lint --configuration .swift-format --recursive Sources Tests

format: $(SWIFT_FORMAT) ## Format code with swift-format
	@echo "$(BLUE)Formatting code with swift-format...$(NC)"
	@$(SWIFT_FORMAT) format --configuration .swift-format --in-place --recursive Sources Tests
	@echo "$(GREEN)✓ Code formatted$(NC)"

clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(APP_BUNDLE) .build *.pkg
	@echo "$(GREEN)✓ Clean complete$(NC)"

install: app ## Install the app to /Applications
	@echo "$(BLUE)Installing to /Applications...$(NC)"
	@pkill Reminder2Cal 2>/dev/null || true
	@rm -rf /Applications/$(APP_BUNDLE)
	@cp -R $(APP_BUNDLE) /Applications/
	@echo "$(GREEN)✓ Installed to /Applications/$(APP_BUNDLE)$(NC)"

# ============================================================================
# App Store Distribution
# ============================================================================

pkg: app ## Create signed .pkg for App Store submission
	@echo "$(BLUE)Creating installer package...$(NC)"
	@echo "  → Fixing permissions and attributes..."
	@chmod -R a+r $(APP_BUNDLE)
	@chmod a+x $(APP_MACOS)/Reminder2Cal
	@find $(APP_BUNDLE) -type d -exec chmod a+rx {} \;
	@xattr -cr $(APP_BUNDLE) 2>/dev/null || true
	@productbuild --component $(APP_BUNDLE) /Applications \
		--sign $(INSTALLER_IDENTITY) \
		$(PKG_NAME)
	@echo "$(GREEN)✓ Package created: $(PKG_NAME)$(NC)"

release: clean pkg ## Full App Store build (clean → build → sign → package)
	@echo "$(GREEN)✓ App Store build complete: $(PKG_NAME)$(NC)"
	@echo ""
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Open Transporter app and upload $(PKG_NAME)"
	@echo "  2. Go to App Store Connect to submit for review"

# ============================================================================
# Info & Validation
# ============================================================================

info: ## Show build information
	@echo "$(BLUE)Build Information:$(NC)"
	@echo "  Product Name:      Reminder2Cal"
	@echo "  Version:           $(VERSION)"
	@echo "  Build Number:      $(BUILD_NUMBER)"
	@echo "  Git Commit:        $(GIT_COMMIT)"
	@echo "  Configuration:     $(BUILD_CONFIG)"
	@echo "  macOS Target:      $(MIN_MACOS_VERSION)+"
	@echo "  Swift Version:     $(SWIFT_VERSION)"
	@echo "  Swift Compiler:    $(shell swift --version | head -n 1)"
	@echo "  Architecture:      Universal (arm64 + x86_64)"
	@echo "  Team ID:           $(TEAM_ID)"
	@echo "  Bundle ID:         com.marcusgrando.Reminder2Cal"
	@echo "  App Bundle:        $(APP_BUNDLE)"
	@echo "  Package:           $(PKG_NAME)"

validate: app ## Validate the app bundle
	@echo "$(BLUE)Validating app bundle...$(NC)"
	@test -d $(APP_BUNDLE) || { echo "$(RED)✗ App bundle not found$(NC)"; exit 1; }
	@test -f $(APP_MACOS)/Reminder2Cal || { echo "$(RED)✗ Executable not found$(NC)"; exit 1; }
	@test -f $(APP_CONTENTS)/Info.plist || { echo "$(RED)✗ Info.plist not found$(NC)"; exit 1; }
	@test -f $(APP_RESOURCES)/icon.icns || { echo "$(RED)✗ Icon not found$(NC)"; exit 1; }
	@test -f $(APP_RESOURCES)/PrivacyInfo.xcprivacy || { echo "$(RED)✗ PrivacyInfo.xcprivacy not found$(NC)"; exit 1; }
	@plutil -lint $(APP_CONTENTS)/Info.plist > /dev/null || { echo "$(RED)✗ Invalid Info.plist$(NC)"; exit 1; }
	@plutil -lint $(APP_RESOURCES)/PrivacyInfo.xcprivacy > /dev/null || { echo "$(RED)✗ Invalid PrivacyInfo.xcprivacy$(NC)"; exit 1; }
	@codesign --verify $(APP_BUNDLE) 2>/dev/null || { echo "$(RED)✗ Invalid signature$(NC)"; exit 1; }
	@echo "$(GREEN)✓ App bundle is valid$(NC)"

# ============================================================================
# Special Targets
# ============================================================================

.DEFAULT_GOAL := all
