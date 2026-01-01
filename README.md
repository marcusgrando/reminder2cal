# Reminder2Cal

**Never Miss a Reminder Again**

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-GPL%20v3-green.svg)](LICENSE)

Reminder2Cal bridges the gap between Apple Reminders and Calendar by automatically syncing your time-based reminders as calendar events — complete with the persistent alarms that Reminders lacks.

## The Problem

Apple Reminders notifications are easy to dismiss and forget. Once you swipe away that notification, your reminder disappears into the void. There's no persistent alarm, no way to ensure you actually acknowledge important tasks.

## The Solution

Reminder2Cal automatically creates calendar events for your reminders, giving you access to Calendar's powerful alarm system. Pair it with apps like [Calalarm](https://apps.apple.com/br/app/calalarm-calendar/id1590304931) on iOS for alarms that keep ringing until you acknowledge them.

## Key Features

- **Automatic Sync** — Seamlessly syncs reminders to calendar events
- **Persistent Alarms** — Calendar alarms that won't let you forget
- **Menu Bar App** — Runs silently in the background
- **Selective Sync** — Choose which reminder lists to sync
- **Customizable** — Configure sync intervals, event duration, and alarm timing
- **Privacy First** — All data stays on your Mac, no cloud required

## Perfect For

- Medication reminders that can't be ignored
- Important appointments and deadlines
- Time-sensitive tasks requiring acknowledgment
- Anyone who needs more reliable reminder notifications

## Download

**[Get it on the Mac App Store](https://apps.apple.com/app/reminder2cal)** — The easiest way to install and receive automatic updates.

## Getting Started

1. After launching, you'll see a small icon in your menu bar (top-right of your screen)
2. Click the icon and select **Settings**
3. Choose which reminder list to sync and which calendar to use
4. Click **Save** — that's it!

> **Tip:** Create a dedicated calendar (e.g., "Reminders") in the Calendar app for synced events. This keeps your calendar organized. Events created by Reminder2Cal are marked with " - R2C" for easy identification.

## How It Works

1. Reminder2Cal watches your selected reminder lists for changes
2. When a reminder has a due date/time, it creates a matching calendar event
3. Calendar events include alarms that persist until you acknowledge them
4. When you complete a reminder, the calendar event is automatically removed
5. Changes sync automatically every few minutes (configurable in Settings)

> **Note:** Reminder2Cal runs in your menu bar and syncs while your Mac is awake. Reminders created or modified on your iPhone/iPad will sync to your calendar as soon as your Mac wakes up.

## Privacy

- All data stays local on your Mac
- No analytics or tracking
- No internet connection required
- Open source for full transparency

---

## Building from Source

For developers who prefer to build from source:

```bash
git clone https://github.com/marcusgrando/reminder2cal.git
cd reminder2cal
make install
```

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode Command Line Tools
- Swift 5.9+

### Build Commands

| Command | Description |
|---------|-------------|
| `make app` | Build the application bundle |
| `make run` | Build and launch the app |
| `make install` | Install to /Applications |
| `make test` | Run unit tests |
| `make lint` | Check code style |
| `make format` | Format code with swift-format |

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) before submitting a pull request.

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.

---

**Made with Swift for macOS**
