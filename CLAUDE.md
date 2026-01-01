# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
make app              # Build complete .app bundle (default)
make build            # Compile universal binary (ARM64 + x86_64)
make run              # Build and launch the app
make test             # Run all unit tests
make lint             # Check code style with swift-format
make format           # Format code with swift-format
make clean            # Remove build artifacts
make install          # Install to /Applications
make dmg              # Create distribution DMG
make release          # Full release build with notarization
```

## Architecture

Reminder2Cal is a native macOS menu bar application that synchronizes Reminders with Calendar. It uses a two-layer architecture:

### Layer 1: Reminder2CalCore (Library)
Business logic independent of UI, located in `Sources/Reminder2CalCore/`:
- **Configuration/AppConfig.swift**: Configuration management with plist persistence. ObservableObject for SwiftUI binding.
- **Services/SyncService.swift**: Core synchronization engine using EventKit.

### Layer 2: Reminder2Cal (Application)
UI and lifecycle management in `Sources/Reminder2Cal/`:
- **App/**: Entry points (AppDelegate.swift, Reminder2CalApp.swift)
- **Features/**: Feature-specific views organized by domain
  - **Settings/SettingsView.swift**: Configuration UI
  - **About/AboutView.swift**: App information
- **Shared/**: Reusable components
  - **Components/EscapableWindow.swift**: Custom window handling
  - **Extensions/NSImage+Resize.swift**: Image utilities
- **Infrastructure/Logger.swift**: File-based logging

### Sync Flow
1. Trigger: periodic timer or EventKit change notification (debounced 1.5s)
2. Fetch reminders from configured account/list within date range
3. Fetch existing events from destination calendar
4. Compare using unique key: `title [calendar] | date | notes | completion`
5. Create missing events, delete orphaned events (with confirmation for bulk deletions)
6. `isMakingChanges` flag prevents self-triggered sync loops

## Key Files

- `VERSION`: Single source of truth for version number
- `Configuration/Info.plist`: Bundle metadata, LSUIElement=true (menu bar app)
- `Configuration/Entitlements.plist`: Calendar and Reminders access entitlements
- `Resources/icon.icns`: App icon
- `Resources/Assets.xcassets/`: Asset catalog
- `Package.swift`: SPM configuration with two targets
- `.swift-format`: swift-format (Apple) configuration

## Testing

Tests mirror the source structure in `Tests/`:
- `Reminder2CalCoreTests/Configuration/AppConfigTests.swift`
- `Reminder2CalCoreTests/Services/SyncServiceTests.swift`

Run with `make test` or `swift test`.

## Code Quality

```bash
make lint             # Check code style (swift-format lint)
make format           # Auto-format code (swift-format)
```

## Requirements

- macOS 14.0+ (Sonoma)
- Swift 5.9+
- Xcode Command Line Tools
- Developer ID certificate for distribution builds
