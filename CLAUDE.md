# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
make              # Build Release (universal binary via xcodebuild)
make debug        # Build Debug (for development)
make run          # Build and launch the app
make clean        # Remove build artifacts
make lint         # Check code style with swift-format
make format       # Format code with swift-format
make install      # Install to /Applications
make info         # Show build information
```

### App Store Distribution

```bash
make archive      # Create .xcarchive for App Store
make pkg          # Export signed .pkg from archive
make upload       # Upload to App Store Connect (requires .env.local)
make release      # Full: clean -> archive -> pkg -> upload
```

## Architecture

Reminder2Cal is a native macOS menu bar application that synchronizes Reminders with Calendar. Built with Xcode and distributed via the Mac App Store.

### Source Structure

**Sources/Reminder2CalCore/** - Business logic (no UI dependencies):
- `Configuration/AppConfig.swift` - Configuration management with plist persistence
- `Services/SyncService.swift` - Core synchronization engine using EventKit

**Sources/Reminder2Cal/** - UI and app lifecycle:
- `App/` - Entry points (AppDelegate.swift, Reminder2CalApp.swift)
- `Features/` - Feature views organized by domain (Settings, About, Subscription)
- `Shared/` - Reusable components and extensions
- `Infrastructure/Logger.swift` - File-based logging

### Sync Flow
1. Trigger: periodic timer or EventKit change notification (debounced 1.5s)
2. Fetch reminders from configured account/list within date range
3. Fetch existing events from destination calendar
4. Compare using unique key: `title [calendar] | date | notes | completion`
5. Create missing events, delete orphaned events (with confirmation for bulk deletions)
6. `isMakingChanges` flag prevents self-triggered sync loops

## Key Files

- `Reminder2Cal.xcodeproj/` - Xcode project (build system)
- `Configuration/Info.plist` - Bundle metadata, version number, LSUIElement=true
- `Configuration/Entitlements.plist` - Calendar and Reminders access entitlements
- `Configuration/ExportOptions.plist` - App Store export settings
- `Resources/Assets.xcassets/` - Asset catalog (icons, colors)
- `Package.swift` - SPM config for swift-format dependency only
- `.swift-format` - Code style configuration

## Code Quality

```bash
make lint         # Check code style (swift-format lint)
make format       # Auto-format code (swift-format)
```

## App Store Upload

Requires API Key from App Store Connect:
1. Create at: https://appstoreconnect.apple.com/access/integrations/api
2. Download the `.p8` key file
3. Create `.env.local` (see `.env.local.example`):
   ```
   API_KEY = YOUR_KEY_ID
   API_ISSUER = YOUR_ISSUER_ID
   ```
4. Run `make upload` or `make release`

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+ with Command Line Tools
- Apple Developer account for distribution
