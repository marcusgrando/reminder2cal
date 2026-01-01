# Reminder2Cal

**Never Miss a Reminder Again**

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-GPL%20v3-green.svg)](LICENSE)

Reminder2Cal bridges the gap between Apple Reminders and Calendar by automatically syncing your time-based reminders as calendar events — complete with the persistent alarms that Reminders lacks.

## The Problem

Apple Reminders notifications are easy to dismiss and forget. Once you swipe away that notification, your reminder disappears into the void. There's no persistent alarm, no way to ensure you actually acknowledge important tasks.

## The Solution

Reminder2Cal automatically creates calendar events for your reminders, giving you access to Calendar's powerful alarm system. Pair it with apps like [Calalarm](https://apps.apple.com/app/calalarm/id594286325) on iOS for alarms that keep ringing until you acknowledge them.

## Key Features

- **Automatic Sync** — Seamlessly syncs reminders to calendar events
- **Persistent Alarms** — Calendar alarms that won't let you forget
- **Menu Bar App** — Runs silently in the background
- **Selective Sync** — Choose which reminder lists to sync
- **Customizable** — Configure sync intervals, event duration, and alarm timing
- **Privacy First** — All data stays on your Mac, no cloud required
- **Native Performance** — Built with Swift using Apple's native APIs

## Perfect For

- Medication reminders that can't be ignored
- Important appointments and deadlines
- Time-sensitive tasks requiring acknowledgment
- Anyone who needs more reliable reminder notifications

## Requirements

- macOS 14.0 (Sonoma) or later
- Calendar and Reminders access permissions

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/marcusgrando/reminder2cal.git
cd reminder2cal

# Build and install
make install
```

### Build Commands

| Command | Description |
|---------|-------------|
| `make app` | Build the application bundle |
| `make run` | Build and launch the app |
| `make install` | Install to /Applications |
| `make test` | Run unit tests |
| `make lint` | Check code style |
| `make format` | Format code with swift-format |

## Configuration

After launching, click the menu bar icon to access Settings:

1. **Reminder Source** — Select which account and lists to sync
2. **Calendar Destination** — Choose the target calendar
3. **Sync Interval** — How often to check for changes (1-60 minutes)
4. **Event Duration** — Default length of created events
5. **Alarm Offset** — When to trigger the alarm before the event

## How It Works

1. Reminder2Cal monitors your selected reminder lists for changes
2. When a reminder has a due date/time, it creates a corresponding calendar event
3. Calendar events include alarms that persist until acknowledged
4. Completed reminders are automatically cleaned up from the calendar
5. Changes sync in real-time with intelligent debouncing

## Privacy

Reminder2Cal is designed with privacy in mind:

- All data stays local on your Mac
- No analytics or tracking
- No network connections required
- Open source for full transparency

## Development

### Project Structure

```
├── Sources/
│   ├── Reminder2Cal/           # Main application
│   │   ├── App/               # Entry points and lifecycle
│   │   ├── Features/          # Settings and About views
│   │   ├── Shared/            # Reusable components
│   │   └── Infrastructure/    # Logging utilities
│   └── Reminder2CalCore/       # Business logic library
│       ├── Configuration/     # App settings management
│       └── Services/          # Sync engine
├── Resources/                  # Icons and assets
├── Configuration/              # Build configs and plists
└── Tests/                      # Unit tests
```

### Code Quality

```bash
# Check code style (swift-format is built automatically from Package.swift)
make lint

# Format code
make format
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) before submitting a pull request.

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.

---

**Made with Swift for macOS**
