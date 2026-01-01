# Changelog

All notable changes to Reminder2Cal will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-01

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
