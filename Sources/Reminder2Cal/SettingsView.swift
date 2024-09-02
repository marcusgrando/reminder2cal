import SwiftUI
import AppConfig
import Combine
import ServiceManagement

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
    @State private var defaultHour: Int
    @State private var defaultMinute: Int
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
        self._maxDeletionsWithoutConfirmation = State(initialValue: appConfig.maxDeletionsWithoutConfirmation)
        self._timerInterval = State(initialValue: appConfig.timerInterval)
        self._requestAccessInterval = State(initialValue: appConfig.requestAccessInterval)
        self._eventDurationMinutes = State(initialValue: appConfig.eventDurationMinutes)
        self._alarmOffsetMinutes = State(initialValue: appConfig.alarmOffsetMinutes)
        self._reminderLists = State(initialValue: ["Inbox", "Work", "Personal", "All"])
        self._loginItemEnabled = State(initialValue: appConfig.loginItemEnabled)
        self._defaultHour = State(initialValue: appConfig.defaultHour)
        self._defaultMinute = State(initialValue: appConfig.defaultMinute)
        self._accounts = State(initialValue: ["iCloud", "Google", "Outlook"])
        self._calendars = State(initialValue: ["Reminders", "Work", "Personal"])
        self.appConfig = appConfig
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack {
            Form {
                Section(header: Text("Account Settings").bold().padding(.top, 10)) {
                    Divider()
                    Picker("Account", selection: $accountName) {
                        ForEach(accounts, id: \.self) { account in
                            Text(account)
                        }
                    }
                }
                
                Section(header: Text("Calendar Settings").bold().padding(.top, 10)) {
                    Divider()
                    Picker("Calendar", selection: $calendarName) {
                        ForEach(calendars, id: \.self) { calendar in
                            Text(calendar)
                        }
                    }
                }

                Section(header: Text("Reminder List").bold().padding(.top, 10)) {
                    Divider()
                    Picker("Reminder List", selection: $reminderListName) {
                        ForEach(reminderLists, id: \.self) { list in
                            Text(list)
                        }
                    }
                }
                
                Section(header: Text("Sync Settings").bold().padding(.top, 10)) {
                    Divider()
                    TextField("Number of Days for Search", value: $numberOfDaysForSearch, formatter: NumberFormatter())
                        .onChange(of: numberOfDaysForSearch) { newValue in
                            numberOfDaysForSearch = min(max(newValue, 1), 365)
                        }
                    TextField("Max Deletions Without Confirmation", value: $maxDeletionsWithoutConfirmation, formatter: NumberFormatter())
                        .onChange(of: maxDeletionsWithoutConfirmation) { newValue in
                            maxDeletionsWithoutConfirmation = min(max(newValue, 1), 100)
                        }
                }
                
                Section(header: Text("Running Settings").bold().padding(.top, 10)) {
                    Divider()
                    TextField("Timer Interval (seconds)", value: $timerInterval, formatter: NumberFormatter())
                        .onChange(of: timerInterval) { newValue in
                            timerInterval = min(max(newValue, 60), 3600)
                        }
                    TextField("Request Access Interval (seconds)", value: $requestAccessInterval, formatter: NumberFormatter())
                        .onChange(of: requestAccessInterval) { newValue in
                            requestAccessInterval = min(max(newValue, 60), 3600)
                        }
                }
                
                Section(header: Text("Calendar Settings").bold().padding(.top, 10)) {
                    Divider()
                    TextField("Event Duration (minutes)", value: $eventDurationMinutes, formatter: NumberFormatter())
                        .onChange(of: eventDurationMinutes) { newValue in
                            eventDurationMinutes = min(max(newValue, 1), 1440)
                        }
                    TextField("Alarm Offset (minutes)", value: $alarmOffsetMinutes, formatter: NumberFormatter())
                    TextField("Reminders without time use", text: Binding(
                        get: { String(format: "%02d:%02d", defaultHour, defaultMinute) },
                        set: { newValue in
                            let components = newValue.split(separator: ":").map { Int($0) ?? 0 }
                            if components.count == 2 {
                                defaultHour = components[0]
                                defaultMinute = components[1]
                            }
                        }
                    ))
                }
                
                Section(header: Text("Login Item").bold().padding(.top, 10)) {
                    Divider()
                    Toggle(isOn: $loginItemEnabled) {
                        Text("Start with Login")
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: loginItemEnabled) { newValue in
                        toggleLoginItem(newValue)
                    }
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                Spacer()
                Button("Save") {
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
                    appConfig.defaultHour = defaultHour
                    appConfig.defaultMinute = defaultMinute
                    appConfig.saveConfig()
                    onSave()
                }
            }
            .padding()
        }
        .onAppear {
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 53 { // Key 53 = ESC code
                    onCancel()
                    return nil
                }
                return event
            }
        }
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
