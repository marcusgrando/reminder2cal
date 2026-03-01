# Changelog

All notable changes to Reminder2Cal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.5] - 2026-03-01

### Fixed

- Prevent crash when permissions are revoked and app is reopened
- Request Calendar/Reminders access before loading pickers in Settings
- Add sandbox and privacy entitlements for CI builds

### Changed

- Remove App Store references, distribute via GitHub Releases

## [1.1.4] - 2026-02-15

### Changed

- Migrate from App Store subscription model to free open-source distribution
- Add GitHub Releases CI/CD with DMG packaging and notarization
- Add Applications shortcut to DMG

## [1.1.3] - 2026-02-01

### Changed

- Harden release workflow with explicit permissions and environment
- Inject app version from git tag in CI builds
- Add secure timestamp and disable get-task-allow for notarization

## [1.1.2] - 2026-01-17

### Changed

- Improved Settings window layout and spacing
- Enhanced Subscription view with consistent visual design

## [1.1.0] - 2026-01-01

### Added

- " - R2C" suffix on synced events to distinguish them from manual calendar entries

### Changed

- Only delete events with R2C suffix, protecting user-created calendar events

## [1.0.0] - 2025-12-26

### Added

- Initial release
- Automatic sync between Reminders and Calendar
- Menu bar application with silent background operation
- Settings window for configuration:
  - Select reminder account and lists to sync
  - Select destination calendar
  - Configure sync interval
  - Set event duration and alarm offset
- Debounced sync on Reminders/Calendar changes
- Periodic sync timer
- Unique key matching to prevent duplicate events
- Bulk deletion confirmation dialog
- File-based logging
- Universal binary (Intel + Apple Silicon)
- Code signing and notarization support

### Security

- Hardened runtime enabled
- Sandboxed with Calendar and Reminders entitlements
- All data stays local on user's Mac
