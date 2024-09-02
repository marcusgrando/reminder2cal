import SwiftUI
import AppConfig
import Combine

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
                Section(header: Text("Account Settings").frame(maxWidth: .infinity, alignment: .leading).bold().padding(.leading, 15)) {
                    VStack {
                        HStack {
                            Text("Account")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 20)
                            Spacer().frame(width: 10)
                            Picker("", selection: $accountName) {
                                ForEach(accounts, id: \.self) { account in
                                    Text(account)
                                }
                            }
                            Spacer().frame(width: 10)
                        }
                    }
                }
                
                Section(header: Text("Calendar Settings").frame(maxWidth: .infinity, alignment: .leading).bold().padding(.leading, 15)) {
                    HStack(alignment: .top) {
                        Spacer().frame(width: 10)
                        VStack(alignment: .leading) {
                            Text("Calendar")
                                .padding(.leading, 20)
                        }
                        Spacer().frame(width: 10)
                        Picker("", selection: $calendarName) {
                            ForEach(calendars, id: \.self) { calendar in
                                Text(calendar)
                            }
                        }
                        Spacer().frame(width: 10)
                    }
                }
                
                Section(header: Text("Reminder List").frame(maxWidth: .infinity, alignment: .leading).bold().padding(.leading, 15)) {
                    HStack(alignment: .top) {
                        Spacer().frame(width: 10)
                        VStack(alignment: .leading) {
                            Text("Reminder List")
                                .padding(.leading, 20)
                        }
                        Spacer().frame(width: 10)
                        Picker("", selection: $reminderListName) {
                            ForEach(reminderLists, id: \.self) { list in
                                Text(list)
                            }
                        }
                        Spacer().frame(width: 10)
                    }
                }
                
                Section(header: Text("Search Settings").frame(maxWidth: .infinity, alignment: .leading).bold().padding(.leading, 15)) {
                    HStack {
                        Spacer().frame(width: 10)
                        VStack(alignment: .leading) {
                            Text("Number of Days for Search")
                                .padding(.leading, 20)
                            Text("Max Deletions Without Confirmation")
                                .padding(.leading, 20)
                        }
                        Spacer().frame(width: 10)
                        VStack {
                            TextField("", value: $numberOfDaysForSearch, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: numberOfDaysForSearch) { newValue in
                                    if newValue < 1 {
                                        numberOfDaysForSearch = 1
                                    } else if newValue > 365 {
                                        numberOfDaysForSearch = 365
                                    }
                                }
                            TextField("", value: $maxDeletionsWithoutConfirmation, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: maxDeletionsWithoutConfirmation) { newValue in
                                    if newValue < 1 {
                                        maxDeletionsWithoutConfirmation = 1
                                    } else if newValue > 100 {
                                        maxDeletionsWithoutConfirmation = 100
                                    }
                                }
                        }
                        Spacer().frame(width: 10)
                    }
                }
                
                Section(header: Text("Timer Settings").frame(maxWidth: .infinity, alignment: .leading).bold().padding(.leading, 15)) {
                    HStack {
                        Spacer().frame(width: 10)
                        VStack(alignment: .leading) {
                            Text("Timer Interval (seconds)")
                                .padding(.leading, 20)
                            Text("Request Access Interval (seconds)")
                                .padding(.leading, 20)
                        }
                        Spacer().frame(width: 10)
                        VStack {
                            TextField("", value: $timerInterval, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: timerInterval) { newValue in
                                    if newValue < 60 {
                                        timerInterval = 60
                                    } else if newValue > 3600 {
                                        timerInterval = 3600
                                    }
                                }
                            TextField("", value: $requestAccessInterval, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: requestAccessInterval) { newValue in
                                    if newValue < 60 {
                                        requestAccessInterval = 60
                                    } else if newValue > 3600 {
                                        requestAccessInterval = 3600
                                    }
                                }
                        }
                        Spacer().frame(width: 10)
                    }
                }
                
                Section(header: Text("Event Settings").frame(maxWidth: .infinity, alignment: .leading).bold().padding(.leading, 15)) {
                    HStack {
                        Spacer().frame(width: 10)
                        VStack(alignment: .leading) {
                            Text("Event Duration (minutes)")
                                .padding(.leading, 20)
                            Text("Alarm Offset (minutes)")
                                .padding(.leading, 20)
                        }
                        Spacer().frame(width: 10)
                        VStack {
                            TextField("", value: $eventDurationMinutes, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: eventDurationMinutes) { newValue in
                                    if newValue < 1 {
                                        eventDurationMinutes = 1
                                    } else if newValue > 1440 {
                                        eventDurationMinutes = 1440
                                    }
                                }
                            TextField("", value: $alarmOffsetMinutes, formatter: NumberFormatter())
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        Spacer().frame(width: 10)
                    }
                }
                
                Section(header: Text("Reminders without Time").frame(maxWidth: .infinity, alignment: .leading).bold().padding(.leading, 15)) {
                    HStack {
                        Spacer().frame(width: 10)
                        VStack(alignment: .leading) {
                            Text("HH:MM")
                                .padding(.leading, 20)
                        }
                        Spacer().frame(width: 10)
                        TextField("", text: Binding(
                            get: {
                                String(format: "%02d:%02d", defaultHour, defaultMinute)
                            },
                            set: { newValue in
                                let components = newValue.split(separator: ":").map { Int($0) ?? 0 }
                                if components.count == 2 {
                                    defaultHour = components[0]
                                    defaultMinute = components[1]
                                }
                            }
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        Spacer().frame(width: 10)
                    }
                }
                
                Section {
                    HStack {
                        Spacer().frame(width: 10)
                        Text("Start with Login")
                            .padding(.leading, 20)
                        Spacer().frame(width: 10)
                        Toggle("", isOn: $loginItemEnabled)
                            .toggleStyle(SwitchToggleStyle())
                        Spacer().frame(width: 10)
                    }
                }
            }
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(appConfig: AppConfig(), onSave: {}, onCancel: {})
    }
}
