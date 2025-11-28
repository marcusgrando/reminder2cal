import AppConfig
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var accountName: String
    @State private var calendarName: String
    @State private var reminderListName: String
    @State private var numberOfDaysForSearch: Int
    @State private var maxDeletionsWithoutConfirmation: Int
    @State private var timerInterval: TimeInterval
    @State private var requestAccessInterval: TimeInterval
    @State private var eventDurationMinutes: Int
    @State private var alarmOffsetMinutes: Int
    @State private var reminderLists: [String]
    @State private var loginItemEnabled: Bool
    @State private var defaultTime: Date
    @State private var accounts: [String]
    @State private var calendars: [String]

    @ObservedObject var appConfig: AppConfig
    var onSave: () -> Void
    var onCancel: () -> Void

    init(appConfig: AppConfig, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._accountName = State(initialValue: appConfig.accountName)
        self._calendarName = State(initialValue: appConfig.calendarName)
        self._reminderListName = State(initialValue: appConfig.reminderListName.first ?? "Inbox")
        self._numberOfDaysForSearch = State(initialValue: appConfig.numberOfDaysForSearch)
        self._maxDeletionsWithoutConfirmation = State(
            initialValue: appConfig.maxDeletionsWithoutConfirmation)
        self._timerInterval = State(initialValue: appConfig.timerInterval)
        self._requestAccessInterval = State(initialValue: appConfig.requestAccessInterval)
        self._eventDurationMinutes = State(initialValue: appConfig.eventDurationMinutes)
        self._alarmOffsetMinutes = State(initialValue: appConfig.alarmOffsetMinutes)
        self._reminderLists = State(initialValue: ["Inbox", "Work", "Personal", "All"])
        self._loginItemEnabled = State(initialValue: appConfig.loginItemEnabled)

        // Initialize defaultTime from hour/minute
        var components = DateComponents()
        components.hour = appConfig.defaultHour
        components.minute = appConfig.defaultMinute
        let date = Calendar.current.date(from: components) ?? Date()
        self._defaultTime = State(initialValue: date)

        self._accounts = State(initialValue: ["iCloud", "Google", "Outlook"])
        self._calendars = State(initialValue: ["Reminders", "Work", "Personal"])
        self.appConfig = appConfig
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(isOn: $loginItemEnabled) {
                        Label {
                            Text("Start with Login")
                        } icon: {
                            Image(systemName: "power")
                                .foregroundColor(.green)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: loginItemEnabled) { newValue in
                        toggleLoginItem(newValue)
                    }
                } header: {
                    Text("General")
                }

                Section {
                    Picker(selection: $accountName) {
                        ForEach(accounts, id: \.self) { account in
                            Text(account)
                        }
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                    }

                    Picker(selection: $calendarName) {
                        ForEach(calendars, id: \.self) { calendar in
                            Text(calendar)
                        }
                    } label: {
                        Label("Calendar", systemImage: "calendar")
                    }

                    Picker(selection: $reminderListName) {
                        ForEach(reminderLists, id: \.self) { list in
                            Text(list)
                        }
                    } label: {
                        Label("Reminder List", systemImage: "list.bullet")
                    }
                } header: {
                    Text("Accounts & Sources")
                }

                Section {
                    Stepper(value: $numberOfDaysForSearch, in: 1...365) {
                        HStack {
                            Label("Search Range", systemImage: "magnifyingglass")
                            Spacer()
                            Text("\(numberOfDaysForSearch) days")
                                .foregroundColor(.secondary)
                        }
                    }

                    Stepper(value: $maxDeletionsWithoutConfirmation, in: 1...100) {
                        HStack {
                            Label("Max Auto-Deletions", systemImage: "trash")
                            Spacer()
                            Text("\(maxDeletionsWithoutConfirmation) items")
                                .foregroundColor(.secondary)
                        }
                    }

                    Stepper(
                        value: Binding(
                            get: { timerInterval / 60 },
                            set: { timerInterval = $0 * 60 }
                        ), in: 1...60, step: 1
                    ) {
                        HStack {
                            Label("Sync Interval", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            Text("\(Int(timerInterval / 60)) min")
                                .foregroundColor(.secondary)
                        }
                    }

                    Stepper(
                        value: Binding(
                            get: { requestAccessInterval / 60 },
                            set: { requestAccessInterval = $0 * 60 }
                        ), in: 1...60, step: 1
                    ) {
                        HStack {
                            Label("Access Request Interval", systemImage: "lock.shield")
                            Spacer()
                            Text("\(Int(requestAccessInterval / 60)) min")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Sync Configuration")
                }

                Section {
                    Stepper(value: $eventDurationMinutes, in: 5...1440, step: 5) {
                        HStack {
                            Label("Event Duration", systemImage: "clock")
                            Spacer()
                            Text("\(eventDurationMinutes) min")
                                .foregroundColor(.secondary)
                        }
                    }

                    Stepper(value: $alarmOffsetMinutes, in: 0...1440, step: 5) {
                        HStack {
                            Label("Alarm Offset", systemImage: "bell")
                            Spacer()
                            Text("\(alarmOffsetMinutes) min")
                                .foregroundColor(.secondary)
                        }
                    }

                    DatePicker(selection: $defaultTime, displayedComponents: .hourAndMinute) {
                        Label("Default Time", systemImage: "clock.fill")
                    }
                } header: {
                    Text("Event Defaults")
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 {  // Key 53 = ESC code
                    onCancel()
                    return nil
                }
                return event
            }
        }
    }

    private func saveSettings() {
        appConfig.accountName = accountName
        appConfig.calendarName = calendarName
        appConfig.reminderListName = [reminderListName]
        appConfig.numberOfDaysForSearch = numberOfDaysForSearch
        appConfig.maxDeletionsWithoutConfirmation = maxDeletionsWithoutConfirmation
        appConfig.timerInterval = timerInterval
        appConfig.requestAccessInterval = requestAccessInterval
        appConfig.eventDurationMinutes = eventDurationMinutes
        appConfig.alarmOffsetMinutes = alarmOffsetMinutes
        appConfig.loginItemEnabled = loginItemEnabled

        let components = Calendar.current.dateComponents([.hour, .minute], from: defaultTime)
        appConfig.defaultHour = components.hour ?? 9
        appConfig.defaultMinute = components.minute ?? 0

        appConfig.saveConfig()
        onSave()
    }

    private func toggleLoginItem(_ isEnabled: Bool) {
        let appService = SMAppService.mainApp
        do {
            if isEnabled {
                try appService.register()
            } else {
                try appService.unregister()
            }
            appConfig.loginItemEnabled = isEnabled
        } catch {
            NSLog("[R2CLog] Error setting login item status: \(error)")
            loginItemEnabled = !isEnabled
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appConfig: AppConfig(), onSave: {}, onCancel: {})
    }
}
