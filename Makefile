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
SWIFT_FLAGS := --configuration $(BUILD_CONFIG) -Xswiftc -O -Xswiftc -whole-module-optimization
MIN_MACOS_VERSION := 14.0
SWIFT_VERSION := 5.9

# Paths
BUILD_DIR := .build/$(BUILD_CONFIG)
EXECUTABLE := $(BUILD_DIR)/Reminder2Cal
APP_BUNDLE := Reminder2Cal.app
APP_CONTENTS := $(APP_BUNDLE)/Contents
APP_MACOS := $(APP_CONTENTS)/MacOS
APP_RESOURCES := $(APP_CONTENTS)/Resources
APP_FRAMEWORKS := $(APP_CONTENTS)/Frameworks
ENTITLEMENTS := Entitlements.plist

# Code Signing & Notarization
SIGNING_IDENTITY := "Developer ID Application: Marcus Nestor Alves Grando (MY427949GW)"
CODESIGN_FLAGS := --force --timestamp --options runtime --entitlements $(ENTITLEMENTS)
NOTARIZE_PROFILE := "notarytool-profile"
TEAM_ID := MY427949GW

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

# ============================================================================
# Main Targets
# ============================================================================

.PHONY: all build app clean install run test help version

all: app ## Build the complete application bundle (default target)

help: ## Show this help message
	@echo "$(BLUE)Reminder2Cal Build System$(NC)"
	@echo "Version: $(VERSION) (Build $(BUILD_NUMBER))"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'

version: ## Display current version
	@echo "Version: $(VERSION)"
	@echo "Build: $(BUILD_NUMBER)"

# ============================================================================
# Build Targets
# ============================================================================

build: ## Build the Swift executable
	@echo "$(BLUE)Building Reminder2Cal $(VERSION) ($(GIT_COMMIT))...$(NC)"
	$(SWIFT) $(SWIFT_FLAGS)
	@echo "$(GREEN)✓ Build complete$(NC)"

build-universal: ## Build universal binary (Intel + Apple Silicon)
	@echo "$(BLUE)Building universal binary...$(NC)"
	@swift build --configuration $(BUILD_CONFIG) --arch arm64 --arch x86_64
	@echo "$(GREEN)✓ Universal binary build complete$(NC)"

$(EXECUTABLE):
	@$(MAKE) -s build

app: $(EXECUTABLE) ## Create the .app bundle
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
	@cp icon.icns $(APP_RESOURCES)/
	@cp reminder2cal.svg $(APP_RESOURCES)/
	@xattr -c $(APP_RESOURCES)/icon.icns 2>/dev/null || true

update-info-plist:
	@echo "  → Updating Info.plist with version $(VERSION)..."
	@cp Info.plist $(APP_CONTENTS)/
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
		Assets.xcassets 2>/dev/null || true

copy-executable:
	@echo "  → Copying executable..."
	@cp $(EXECUTABLE) $(APP_MACOS)/Reminder2Cal

sign-app:
	@echo "  → Code signing with hardened runtime..."
	@if [ -f "$(ENTITLEMENTS)" ]; then \
		codesign $(CODESIGN_FLAGS) --sign $(SIGNING_IDENTITY) $(APP_BUNDLE); \
	else \
		codesign --force --timestamp --options runtime --sign $(SIGNING_IDENTITY) $(APP_BUNDLE); \
	fi
	@codesign --verify --verbose=2 $(APP_BUNDLE) 2>&1 | head -n 1
	@echo "$(GREEN)  ✓ Code signing complete$(NC)"

verify-signature: ## Verify code signature
	@echo "$(BLUE)Verifying code signature...$(NC)"
	@codesign --verify --deep --strict --verbose=2 $(APP_BUNDLE)
	@spctl --assess --verbose=4 --type execute $(APP_BUNDLE)
	@echo "$(GREEN)✓ Signature valid$(NC)"

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

profile: ## Build for profiling
	@echo "$(BLUE)Building for profiling...$(NC)"
	@swift build --configuration release -Xswiftc -profile-generate
	@echo "$(GREEN)✓ Profile build complete$(NC)"

test: ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	@swift test

clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(APP_BUNDLE) .build *.dmg
	@pkill Reminder2Cal 2>/dev/null || true
	@echo "$(GREEN)✓ Clean complete$(NC)"

clean-derived: ## Clean derived data (similar to Xcode)
	@echo "$(YELLOW)Cleaning derived data...$(NC)"
	@rm -rf .build
	@rm -rf ~/Library/Developer/Xcode/DerivedData/Reminder2Cal-*
	@echo "$(GREEN)✓ Derived data cleaned$(NC)"

install: app ## Install the app to /Applications
	@echo "$(BLUE)Installing to /Applications...$(NC)"
	@rm -rf /Applications/$(APP_BUNDLE)
	@cp -R $(APP_BUNDLE) /Applications/
	@echo "$(GREEN)✓ Installed to /Applications/$(APP_BUNDLE)$(NC)"

uninstall: ## Uninstall the app from /Applications
	@echo "$(YELLOW)Uninstalling from /Applications...$(NC)"
	@rm -rf /Applications/$(APP_BUNDLE)
	@pkill Reminder2Cal 2>/dev/null || true
	@echo "$(GREEN)✓ Uninstalled$(NC)"

# ============================================================================
# Release Management
# ============================================================================

dmg: app ## Create a DMG for distribution
	@echo "$(BLUE)Creating DMG...$(NC)"
	@rm -f Reminder2Cal.dmg Reminder2Cal-temp.dmg
	@hdiutil create -volname "Reminder2Cal $(VERSION)" \
		-srcfolder $(APP_BUNDLE) \
		-ov -format UDRW \
		Reminder2Cal-temp.dmg
	@hdiutil convert Reminder2Cal-temp.dmg -format UDZO -o Reminder2Cal.dmg
	@rm -f Reminder2Cal-temp.dmg
	@echo "$(GREEN)✓ DMG created: Reminder2Cal.dmg$(NC)"

notarize: dmg ## Notarize the DMG for distribution
	@echo "$(BLUE)Submitting for notarization...$(NC)"
	@xcrun notarytool submit Reminder2Cal.dmg \
		--keychain-profile "$(NOTARIZE_PROFILE)" \
		--wait
	@xcrun stapler staple Reminder2Cal.dmg
	@echo "$(GREEN)✓ DMG notarized and stapled$(NC)"

dist: clean app dmg ## Clean build and create distribution DMG
	@echo "$(GREEN)✓ Distribution build complete$(NC)"
	@echo "$(YELLOW)Note: Run 'make notarize' to notarize for distribution$(NC)"

release: clean verify-signature notarize ## Full release build with notarization
	@echo "$(GREEN)✓ Release build complete and notarized$(NC)"

bump-patch: ## Bump patch version (1.0.0 -> 1.0.1)
	@echo "$(BLUE)Bumping patch version...$(NC)"
	@$(eval NEW_VERSION := $(shell echo $(VERSION) | awk -F. '{print $$1"."$$2"."$$3+1}'))
	@echo $(NEW_VERSION) > VERSION
	@echo "$(GREEN)Version updated: $(VERSION) → $(NEW_VERSION)$(NC)"
	@echo "Don't forget to commit the VERSION file!"

bump-minor: ## Bump minor version (1.0.0 -> 1.1.0)
	@echo "$(BLUE)Bumping minor version...$(NC)"
	@$(eval NEW_VERSION := $(shell echo $(VERSION) | awk -F. '{print $$1"."$$2+1".0"}'))
	@echo $(NEW_VERSION) > VERSION
	@echo "$(GREEN)Version updated: $(VERSION) → $(NEW_VERSION)$(NC)"
	@echo "Don't forget to commit the VERSION file!"

bump-major: ## Bump major version (1.0.0 -> 2.0.0)
	@echo "$(BLUE)Bumping major version...$(NC)"
	@$(eval NEW_VERSION := $(shell echo $(VERSION) | awk -F. '{print $$1+1".0.0"}'))
	@echo $(NEW_VERSION) > VERSION
	@echo "$(GREEN)Version updated: $(VERSION) → $(NEW_VERSION)$(NC)"
	@echo "Don't forget to commit the VERSION file!"

# ============================================================================
# Info Targets
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
	@echo "  Architecture:      $(shell uname -m)"
	@echo "  Signing Identity:  $(SIGNING_IDENTITY)"
	@echo "  Team ID:           $(TEAM_ID)"
	@echo "  Bundle ID:         com.marcusgrando.Reminder2Cal"
	@echo "  App Bundle:        $(APP_BUNDLE)"

check-deps: ## Check for required dependencies
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v swift >/dev/null 2>&1 || { echo "$(RED)✗ Swift not found$(NC)"; exit 1; }
	@command -v xcrun >/dev/null 2>&1 || { echo "$(RED)✗ Xcode command line tools not found$(NC)"; exit 1; }
	@command -v codesign >/dev/null 2>&1 || { echo "$(RED)✗ codesign not found$(NC)"; exit 1; }
	@command -v hdiutil >/dev/null 2>&1 || { echo "$(RED)✗ hdiutil not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All dependencies found$(NC)"
	@echo "  Swift: $$(swift --version | head -n 1)"
	@echo "  Xcode: $$(xcodebuild -version 2>/dev/null | head -n 1 || echo 'Command Line Tools only')"

validate: app ## Validate the app bundle
	@echo "$(BLUE)Validating app bundle...$(NC)"
	@test -d $(APP_BUNDLE) || { echo "$(RED)✗ App bundle not found$(NC)"; exit 1; }
	@test -f $(APP_MACOS)/Reminder2Cal || { echo "$(RED)✗ Executable not found$(NC)"; exit 1; }
	@test -f $(APP_CONTENTS)/Info.plist || { echo "$(RED)✗ Info.plist not found$(NC)"; exit 1; }
	@test -f $(APP_RESOURCES)/icon.icns || { echo "$(RED)✗ Icon not found$(NC)"; exit 1; }
	@plutil -lint $(APP_CONTENTS)/Info.plist > /dev/null || { echo "$(RED)✗ Invalid Info.plist$(NC)"; exit 1; }
	@codesign --verify $(APP_BUNDLE) 2>/dev/null || { echo "$(RED)✗ Invalid signature$(NC)"; exit 1; }
	@echo "$(GREEN)✓ App bundle is valid$(NC)"

analyze: ## Analyze Swift code for issues
	@echo "$(BLUE)Analyzing code...$(NC)"
	@swift build --configuration debug -Xswiftc -analyze
	@echo "$(GREEN)✓ Analysis complete$(NC)"

# ============================================================================
# Special Targets
# ============================================================================

.DEFAULT_GOAL := all
