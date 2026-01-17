import Combine
import EventKit
import Reminder2CalCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var calendarAccountName: String
    @State private var calendarName: String
    @State private var reminderAccountName: String
    @State private var reminderListName: String
    @State private var numberOfDaysForSearch: Int
    @State private var maxDeletionsWithoutConfirmation: Int
    @State private var timerInterval: TimeInterval
    @State private var requestAccessInterval: TimeInterval
    @State private var eventDurationMinutes: Int
    @State private var alarmOffsetMinutes: Int
    @State private var loginItemEnabled: Bool
    @State private var defaultTime: Date

    @State private var calendarAccounts: [String]
    @State private var calendars: [String]
    @State private var reminderAccounts: [String]
    @State private var reminderLists: [String]

    @ObservedObject var appConfig: AppConfig
    var onSave: () -> Void
    var onCancel: () -> Void

    private let eventStore = EKEventStore()

    init(appConfig: AppConfig, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self._calendarAccountName = State(initialValue: appConfig.calendarAccountName)
        self._calendarName = State(initialValue: appConfig.calendarName)
        self._reminderAccountName = State(initialValue: appConfig.reminderAccountName)
        self._reminderListName = State(initialValue: appConfig.reminderListName.first ?? "Inbox")
        self._numberOfDaysForSearch = State(initialValue: appConfig.numberOfDaysForSearch)
        self._maxDeletionsWithoutConfirmation = State(
            initialValue: appConfig.maxDeletionsWithoutConfirmation)
        self._timerInterval = State(initialValue: appConfig.timerInterval)
        self._requestAccessInterval = State(initialValue: appConfig.requestAccessInterval)
        self._eventDurationMinutes = State(initialValue: appConfig.eventDurationMinutes)
        self._alarmOffsetMinutes = State(initialValue: appConfig.alarmOffsetMinutes)
        self._loginItemEnabled = State(initialValue: appConfig.loginItemEnabled)

        // Initialize defaultTime from hour/minute
        var components = DateComponents()
        components.hour = appConfig.defaultHour
        components.minute = appConfig.defaultMinute
        let date = Calendar.current.date(from: components) ?? Date()
        self._defaultTime = State(initialValue: date)

        self._calendarAccounts = State(initialValue: [])
        self._calendars = State(initialValue: [])
        self._reminderAccounts = State(initialValue: [])
        self._reminderLists = State(initialValue: [])
        self.appConfig = appConfig
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(isOn: $loginItemEnabled) {
                        Label("Start with Login", systemImage: "power")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: loginItemEnabled) { _, newValue in
                        toggleLoginItem(newValue)
                    }
                } header: {
                    Text("General")
                }

                Section {
                    Picker(selection: $reminderAccountName) {
                        ForEach(reminderAccounts, id: \.self) { account in
                            Text(account)
                        }
                    } label: {
                        Label("Reminder Account", systemImage: "person.crop.circle")
                    }

                    Picker(selection: $reminderListName) {
                        ForEach(reminderLists, id: \.self) { list in
                            Text(list)
                        }
                    } label: {
                        Label("Reminder List", systemImage: "list.bullet")
                    }
                } header: {
                    Text("Reminder Source")
                }

                Section {
                    Picker(selection: $calendarAccountName) {
                        ForEach(calendarAccounts, id: \.self) { account in
                            Text(account)
                        }
                    } label: {
                        Label("Calendar Account", systemImage: "person.crop.circle")
                    }

                    Picker(selection: $calendarName) {
                        ForEach(calendars, id: \.self) { calendar in
                            Text(calendar)
                        }
                    } label: {
                        Label("Calendar", systemImage: "calendar")
                    }
                } header: {
                    Text("Calendar Destination")
                } footer: {
                    Label(
                        "Tip: Create a dedicated calendar (e.g., \"Reminders\") for best results. Events created by Reminder2Cal are marked with \" - R2C\" suffix.",
                        systemImage: "lightbulb.fill"
                    )
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .symbolRenderingMode(.multicolor)
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
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    saveSettings()
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 450, maxWidth: .infinity, minHeight: 750, maxHeight: .infinity)
        .onAppear {
            loadCalendarAccounts()
            loadCalendars()
            loadReminderAccounts()
            loadReminderLists()
        }
        .onChange(of: calendarAccountName) { _, _ in
            loadCalendars()
        }
        .onChange(of: reminderAccountName) { _, _ in
            loadReminderLists()
        }
    }

    private func loadCalendarAccounts() {
        var accountNames = Set<String>()

        // Get accounts from calendars
        let allCalendars = eventStore.calendars(for: .event)
        for calendar in allCalendars {
            if let source = calendar.source {
                accountNames.insert(source.title)
            }
        }

        calendarAccounts = Array(accountNames).sorted()

        // If current account doesn't exist, select first available
        if !calendarAccounts.contains(calendarAccountName) && !calendarAccounts.isEmpty {
            calendarAccountName = calendarAccounts[0]
        }
    }

    private func loadCalendars() {
        let allCalendars = eventStore.calendars(for: .event)
        let filteredCalendars = allCalendars.filter { calendar in
            calendar.source?.title == calendarAccountName
        }

        calendars = filteredCalendars.map { $0.title }.sorted()

        // If current calendar doesn't exist in selected account, select first available
        if !calendars.contains(calendarName) && !calendars.isEmpty {
            calendarName = calendars[0]
        }
    }

    private func loadReminderAccounts() {
        var accountNames = Set<String>()

        // Get accounts from reminder lists
        let allReminderLists = eventStore.calendars(for: .reminder)
        for list in allReminderLists {
            if let source = list.source {
                accountNames.insert(source.title)
            }
        }

        reminderAccounts = Array(accountNames).sorted()

        // If current account doesn't exist, select first available
        if !reminderAccounts.contains(reminderAccountName) && !reminderAccounts.isEmpty {
            reminderAccountName = reminderAccounts[0]
        }
    }

    private func loadReminderLists() {
        let allLists = eventStore.calendars(for: .reminder)
        let filteredLists = allLists.filter { list in
            list.source?.title == reminderAccountName
        }

        reminderLists = filteredLists.map { $0.title }.sorted()

        // If current reminder list doesn't exist in selected account, select first available
        if !reminderLists.contains(reminderListName) && !reminderLists.isEmpty {
            reminderListName = reminderLists[0]
        }
    }

    private func saveSettings() {
        if appConfig.calendarAccountName != calendarAccountName {
            appConfig.logger?(
                "Setting changed: Calendar Account from '\(appConfig.calendarAccountName)' to '\(calendarAccountName)'"
            )
            appConfig.calendarAccountName = calendarAccountName
        }
        if appConfig.calendarName != calendarName {
            appConfig.logger?(
                "Setting changed: Calendar from '\(appConfig.calendarName)' to '\(calendarName)'")
            appConfig.calendarName = calendarName
        }
        if appConfig.reminderAccountName != reminderAccountName {
            appConfig.logger?(
                "Setting changed: Reminder Account from '\(appConfig.reminderAccountName)' to '\(reminderAccountName)'"
            )
            appConfig.reminderAccountName = reminderAccountName
        }
        if appConfig.reminderListName.first != reminderListName {
            appConfig.logger?(
                "Setting changed: Reminder List from '\(appConfig.reminderListName.first ?? "")' to '\(reminderListName)'"
            )
            appConfig.reminderListName = [reminderListName]
        }
        if appConfig.numberOfDaysForSearch != numberOfDaysForSearch {
            appConfig.logger?(
                "Setting changed: Search Range from '\(appConfig.numberOfDaysForSearch)' to '\(numberOfDaysForSearch)'"
            )
            appConfig.numberOfDaysForSearch = numberOfDaysForSearch
        }
        if appConfig.maxDeletionsWithoutConfirmation != maxDeletionsWithoutConfirmation {
            appConfig.logger?(
                "Setting changed: Max Auto-Deletions from '\(appConfig.maxDeletionsWithoutConfirmation)' to '\(maxDeletionsWithoutConfirmation)'"
            )
            appConfig.maxDeletionsWithoutConfirmation = maxDeletionsWithoutConfirmation
        }
        if appConfig.timerInterval != timerInterval {
            appConfig.logger?(
                "Setting changed: Sync Interval from '\(appConfig.timerInterval)' to '\(timerInterval)'"
            )
            appConfig.timerInterval = timerInterval
        }
        if appConfig.requestAccessInterval != requestAccessInterval {
            appConfig.logger?(
                "Setting changed: Access Request Interval from '\(appConfig.requestAccessInterval)' to '\(requestAccessInterval)'"
            )
            appConfig.requestAccessInterval = requestAccessInterval
        }
        if appConfig.eventDurationMinutes != eventDurationMinutes {
            appConfig.logger?(
                "Setting changed: Event Duration from '\(appConfig.eventDurationMinutes)' to '\(eventDurationMinutes)'"
            )
            appConfig.eventDurationMinutes = eventDurationMinutes
        }
        if appConfig.alarmOffsetMinutes != alarmOffsetMinutes {
            appConfig.logger?(
                "Setting changed: Alarm Offset from '\(appConfig.alarmOffsetMinutes)' to '\(alarmOffsetMinutes)'"
            )
            appConfig.alarmOffsetMinutes = alarmOffsetMinutes
        }
        if appConfig.loginItemEnabled != loginItemEnabled {
            appConfig.logger?(
                "Setting changed: Start with Login from '\(appConfig.loginItemEnabled)' to '\(loginItemEnabled)'"
            )
            appConfig.loginItemEnabled = loginItemEnabled
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: defaultTime)
        let newHour = components.hour ?? 9
        let newMinute = components.minute ?? 0

        if appConfig.defaultHour != newHour || appConfig.defaultMinute != newMinute {
            appConfig.logger?(
                "Setting changed: Default Time from '\(String(format: "%02d:%02d", appConfig.defaultHour, appConfig.defaultMinute))' to '\(String(format: "%02d:%02d", newHour, newMinute))'"
            )
            appConfig.defaultHour = newHour
            appConfig.defaultMinute = newMinute
        }

        appConfig.saveConfig()
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
