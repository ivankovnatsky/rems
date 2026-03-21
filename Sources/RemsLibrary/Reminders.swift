import ArgumentParser
import EventKit
import Foundation

private let Store = EKEventStore()
private let dateFormatter = RelativeDateTimeFormatter()
private func formattedDueDate(from reminder: EKReminder) -> String? {
    return reminder.dueDateComponents?.date.map {
        dateFormatter.localizedString(for: $0, relativeTo: Date())
    }
}

private extension EKReminder {
    var mappedPriority: EKReminderPriority {
        UInt(exactly: self.priority).flatMap(EKReminderPriority.init) ?? EKReminderPriority.none
    }
}

private func format(_ reminder: EKReminder, at index: Int?, listName: String? = nil) -> String {
    let dateString = formattedDueDate(from: reminder).map { " (\($0))" } ?? ""
    let priorityString = Priority(reminder.mappedPriority).map { " (priority: \($0))" } ?? ""
    let listString = listName.map { "\($0): " } ?? ""
    let notesString = reminder.notes.map { " (\($0))" } ?? ""
    let indexString = index.map { "\($0): " } ?? ""
    return "\(listString)\(indexString)\(reminder.title ?? "<unknown>")\(notesString)\(dateString)\(priorityString)"
}

private func formatTSV(_ reminder: EKReminder, at index: Int?, listName: String? = nil) -> String {
    let id = reminder.calendarItemExternalIdentifier ?? ""
    let list = listName ?? reminder.calendar.title
    let completed = reminder.isCompleted ? "1" : "0"
    let priority = Priority(reminder.mappedPriority)?.rawValue ?? "none"
    let dueDate = formattedDueDate(from: reminder) ?? ""
    let title = reminder.title ?? "<unknown>"
    return "\(id)\t\(list)\t\(completed)\t\(priority)\t\(dueDate)\t\(title)"
}

public enum OutputFormat: String, ExpressibleByArgument {
    case json, plain, tsv, quiet
}

public enum DisplayOptions: String, Decodable {
    case all
    case incomplete
    case complete
}

public enum Priority: String, ExpressibleByArgument {
    case none
    case low
    case medium
    case high

    var value: EKReminderPriority {
        switch self {
            case .none: return .none
            case .low: return .low
            case .medium: return .medium
            case .high: return .high
        }
    }

    init?(_ priority: EKReminderPriority) {
        switch priority {
            case .none: return nil
            case .low: self = .low
            case .medium: self = .medium
            case .high: self = .high
        @unknown default:
            return nil
        }
    }
}

public final class Reminders {
    public static func requestAccess() -> (Bool, Error?) {
        let semaphore = DispatchSemaphore(value: 0)
        var grantedAccess = false
        var returnError: Error? = nil
        if #available(macOS 14.0, *) {
            Store.requestFullAccessToReminders { granted, error in
                grantedAccess = granted
                returnError = error
                semaphore.signal()
            }
        } else {
            Store.requestAccess(to: .reminder) { granted, error in
                grantedAccess = granted
                returnError = error
                semaphore.signal()
            }
        }

        semaphore.wait()
        return (grantedAccess, returnError)
    }

    func getListNames() -> [String] {
        return self.getCalendars().map { $0.title }
    }

    func showLists(outputFormat: OutputFormat) {
        let names = self.getListNames()
        switch outputFormat {
        case .json:
            print(encodeToJson(data: names))
        case .quiet:
            print(names.count)
        case .plain, .tsv:
            for name in names {
                print(name)
            }
        }
    }

    func showAllReminders(dueOn dueDate: DateComponents?, includeOverdue: Bool,
        displayOptions: DisplayOptions, outputFormat: OutputFormat,
        filter: ReminderFilter? = nil
    ) {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: self.getCalendars(), displayOptions: displayOptions) { reminders in
            var filtered = reminders
            if let filter = filter {
                filtered = filter.apply(to: filtered)
            }

            var matchingReminders = [(EKReminder, Int, String)]()
            for (i, reminder) in filtered.enumerated() {
                let listName = reminder.calendar.title
                guard let dueDate = dueDate?.date else {
                    matchingReminders.append((reminder, i, listName))
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                let earlierDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedAscending

                if sameDay || (includeOverdue && earlierDay) {
                    matchingReminders.append((reminder, i, listName))
                }
            }

            switch outputFormat {
            case .json:
                print(encodeToJson(data: matchingReminders.map { $0.0 }))
            case .tsv:
                for (reminder, i, listName) in matchingReminders {
                    print(formatTSV(reminder, at: i, listName: listName))
                }
            case .quiet:
                print(matchingReminders.count)
            case .plain:
                for (reminder, i, listName) in matchingReminders {
                    print(format(reminder, at: i, listName: listName))
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func showListItems(withName name: String, dueOn dueDate: DateComponents?, includeOverdue: Bool,
        displayOptions: DisplayOptions, outputFormat: OutputFormat, sort: Sort, sortOrder: CustomSortOrder)
    {
        let semaphore = DispatchSemaphore(value: 0)
        let calendar = Calendar.current

        self.reminders(on: [self.calendar(withName: name)], displayOptions: displayOptions) { reminders in
            var matchingReminders = [(EKReminder, Int?)]()
            let reminders = sort == .none ? reminders : reminders.sorted(by: sort.sortFunction(order: sortOrder))
            for (i, reminder) in reminders.enumerated() {
                let index = sort == .none ? i : nil
                guard let dueDate = dueDate?.date else {
                    matchingReminders.append((reminder, index))
                    continue
                }

                guard let reminderDueDate = reminder.dueDateComponents?.date else {
                    continue
                }

                let sameDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedSame
                let earlierDay = calendar.compare(
                    reminderDueDate, to: dueDate, toGranularity: .day) == .orderedAscending

                if sameDay || (includeOverdue && earlierDay) {
                    matchingReminders.append((reminder, index))
                }
            }

            switch outputFormat {
            case .json:
                print(encodeToJson(data: matchingReminders.map { $0.0 }))
            case .tsv:
                for (reminder, i) in matchingReminders {
                    print(formatTSV(reminder, at: i))
                }
            case .quiet:
                print(matchingReminders.count)
            case .plain:
                for (reminder, i) in matchingReminders {
                    print(format(reminder, at: i))
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func deleteList(withName name: String, force: Bool = false, deleteItems: Bool = false) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [calendar], displayOptions: .all) { reminders in
            if !reminders.isEmpty && !deleteItems {
                let completed = reminders.filter { $0.isCompleted }.count
                let incomplete = reminders.count - completed
                print("List '\(name)' is not empty: \(incomplete) incomplete, \(completed) completed")
                print("Use --delete-items to delete the list and all its reminders")
                exit(1)
            }

            if !force && !Console.confirm("Delete list '\(name)'?") {
                print("Cancelled")
                semaphore.signal()
                return
            }

            do {
                try Store.removeCalendar(calendar, commit: true)
                print("Deleted list '\(name)'")
            } catch let error {
                print("Failed to delete list with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func newList(with name: String, source requestedSourceName: String?) {
        let store = EKEventStore()
        let sources = store.sources
        guard var source = sources.first else {
            print("No existing list sources were found, please create a list in Reminders.app")
            exit(1)
        }

        if let requestedSourceName = requestedSourceName {
            guard let requestedSource = sources.first(where: { $0.title == requestedSourceName }) else
            {
                print("No source named '\(requestedSourceName)'")
                exit(1)
            }

            source = requestedSource
        } else {
            let uniqueSources = Set(sources.map { $0.title })
            if uniqueSources.count > 1 {
                print("Multiple sources were found, please specify one with --source:")
                for source in uniqueSources {
                    print("  \(source)")
                }

                exit(1)
            }
        }

        let newList = EKCalendar(for: .reminder, eventStore: store)
        newList.title = name
        newList.source = source

        do {
            try store.saveCalendar(newList, commit: true)
            print("Created new list '\(newList.title)'!")
        } catch let error {
            print("Failed create new list with error: \(error)")
            exit(1)
        }
    }

    func renameList(oldName: String, newName: String) {
        let calendar = self.calendar(withName: oldName)

        do {
            calendar.title = newName
            try Store.saveCalendar(calendar, commit: true)
            print("Renamed list '\(oldName)' to '\(newName)'")
        } catch let error {
            print("Failed to rename list with error: \(error)")
            exit(1)
        }
    }

    func edit(itemAtIndex index: String, onListNamed name: String, newText: String?, newNotes: String?, newDueDate: DateComponents? = nil, clearDueDate: Bool = false, newPriority: Priority? = nil, newRecurrence: Recurrence? = nil, newCompletionDate: Date? = nil, displayOptions: DisplayOptions = .incomplete, dryRun: Bool = false) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [calendar], displayOptions: displayOptions) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print("No reminder at index \(index) on \(name)")
                exit(1)
            }

            if dryRun {
                print("Would update reminder '\(reminder.title ?? "<untitled>")'")
                semaphore.signal()
                return
            }

            do {
                reminder.title = newText ?? reminder.title
                reminder.notes = newNotes ?? reminder.notes
                if clearDueDate {
                    reminder.dueDateComponents = nil
                    if let alarms = reminder.alarms {
                        for alarm in alarms where alarm.structuredLocation == nil {
                            reminder.removeAlarm(alarm)
                        }
                    }
                    reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
                } else if let newDueDate = newDueDate {
                    reminder.dueDateComponents = newDueDate
                    if let alarms = reminder.alarms {
                        for alarm in alarms where alarm.structuredLocation == nil {
                            reminder.removeAlarm(alarm)
                        }
                    }
                    if let dueDate = newDueDate.date, newDueDate.hour != nil {
                        reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
                    }
                }
                if let newPriority = newPriority {
                    reminder.priority = Int(newPriority.value.rawValue)
                }
                if let newRecurrence = newRecurrence {
                    reminder.recurrenceRules?.forEach { reminder.removeRecurrenceRule($0) }
                    reminder.addRecurrenceRule(newRecurrence.recurrenceRule)
                }
                if let newCompletionDate = newCompletionDate {
                    reminder.completionDate = newCompletionDate
                }
                try Store.save(reminder, commit: true)
                print("Updated reminder '\(reminder.title ?? "<untitled>")'")
            } catch let error {
                print("Failed to update reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func move(itemAtIndex index: String, fromListNamed sourceName: String, toListNamed targetName: String, createList: Bool = false, displayOptions: DisplayOptions = .incomplete, dryRun: Bool = false) {
        let sourceCalendar = self.calendar(withName: sourceName)
        let targetCalendar = createList
            ? self.calendarOrCreate(withName: targetName, source: sourceCalendar.source)
            : self.calendar(withName: targetName)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [sourceCalendar], displayOptions: displayOptions) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print("No reminder at index \(index) on \(sourceName)")
                exit(1)
            }

            if dryRun {
                print("Would move '\(reminder.title ?? "<untitled>")' from '\(sourceName)' to '\(targetCalendar.title)'")
                semaphore.signal()
                return
            }

            do {
                reminder.calendar = targetCalendar
                try Store.save(reminder, commit: true)
                print("Moved '\(reminder.title ?? "<untitled>")' from '\(sourceName)' to '\(targetCalendar.title)'")
            } catch let error {
                print("Failed to move reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func setComplete(_ complete: Bool, itemsAtIndexes indexes: [String], onListNamed name: String, completionDate: Date? = nil, dryRun: Bool = false) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)
        let displayOptions = complete ? DisplayOptions.incomplete : .complete
        let action = complete ? "Completed" : "Uncompleted"
        var hadError = false

        self.reminders(on: [calendar], displayOptions: displayOptions) { reminders in
            for index in indexes {
                guard let reminder = self.getReminder(from: reminders, at: index) else {
                    // Check if the reminder exists but is already in the target state
                    let oppositeOptions: DisplayOptions = complete ? .complete : .incomplete
                    let oppSemaphore = DispatchSemaphore(value: 0)
                    self.reminders(on: [calendar], displayOptions: oppositeOptions) { allReminders in
                        if let found = self.getReminder(from: allReminders, at: index) {
                            let state = complete ? "completed" : "uncompleted"
                            print("Reminder '\(found.title ?? index)' is already \(state)")
                        } else {
                            print("No reminder at index \(index) on \(name)")
                            hadError = true
                        }
                        oppSemaphore.signal()
                    }
                    oppSemaphore.wait()
                    continue
                }

                if dryRun {
                    print("Would \(action.lowercased()) '\(reminder.title ?? "<untitled>")'")
                    continue
                }

                do {
                    reminder.isCompleted = complete
                    if let completionDate = completionDate {
                        reminder.completionDate = completionDate
                    }
                    try Store.save(reminder, commit: true)
                    print("\(action) '\(reminder.title ?? "<untitled>")'")
                } catch let error {
                    print("Failed to save reminder with error: \(error)")
                    hadError = true
                }
            }

            semaphore.signal()
        }

        semaphore.wait()
        if hadError {
            exit(1)
        }
    }

    func delete(itemAtIndex index: String, onListNamed name: String, displayOptions: DisplayOptions = .incomplete, dryRun: Bool = false, force: Bool = false) {
        let calendar = self.calendar(withName: name)
        let semaphore = DispatchSemaphore(value: 0)

        self.reminders(on: [calendar], displayOptions: displayOptions) { reminders in
            guard let reminder = self.getReminder(from: reminders, at: index) else {
                print(RemsError.reminderNotFound(index).errorDescription!)
                exit(1)
            }

            if dryRun {
                print("Would delete '\(reminder.title ?? "<untitled>")'")
                semaphore.signal()
                return
            }

            if !force && !Console.confirm("Delete '\(reminder.title ?? "<untitled>")'?") {
                print("Cancelled")
                semaphore.signal()
                return
            }

            do {
                try Store.remove(reminder, commit: true)
                print("Deleted '\(reminder.title ?? "<untitled>")'")
            } catch let error {
                print("Failed to delete reminder with error: \(error)")
                exit(1)
            }

            semaphore.signal()
        }

        semaphore.wait()
    }

    func addReminder(
        string: String,
        notes: String?,
        toListNamed name: String,
        dueDateComponents: DateComponents?,
        priority: Priority,
        recurrence: Recurrence?,
        createList: Bool,
        outputFormat: OutputFormat)
    {
        let calendar: EKCalendar
        if createList {
            guard let firstCalendar = self.getCalendars().first else {
                print("No existing list sources were found, please create a list in Reminders.app")
                exit(1)
            }
            calendar = self.calendarOrCreate(withName: name, source: firstCalendar.source)
        } else {
            calendar = self.calendar(withName: name)
        }
        let reminder = EKReminder(eventStore: Store)
        reminder.calendar = calendar
        reminder.title = string
        reminder.notes = notes
        reminder.dueDateComponents = dueDateComponents
        reminder.priority = Int(priority.value.rawValue)
        if let dueDate = dueDateComponents?.date, dueDateComponents?.hour != nil {
            reminder.addAlarm(EKAlarm(absoluteDate: dueDate))
        }

        if let recurrence = recurrence {
            reminder.addRecurrenceRule(recurrence.recurrenceRule)
        }

        do {
            try Store.save(reminder, commit: true)
            switch outputFormat {
            case .json:
                print(encodeToJson(data: reminder))
            case .quiet:
                break
            default:
                print("Added '\(reminder.title ?? "<untitled>")' to '\(calendar.title)'")
            }
        } catch let error {
            print("Failed to save reminder with error: \(error)")
            exit(1)
        }
    }

    // MARK: - Private functions

    private func reminders(
        on calendars: [EKCalendar],
        displayOptions: DisplayOptions,
        completion: @escaping (_ reminders: [EKReminder]) -> Void)
    {
        let predicate = Store.predicateForReminders(in: calendars)
        Store.fetchReminders(matching: predicate) { reminders in
            let reminders = reminders?
                .filter { self.shouldDisplay(reminder: $0, displayOptions: displayOptions) }
            completion(reminders ?? [])
        }
    }

    private func shouldDisplay(reminder: EKReminder, displayOptions: DisplayOptions) -> Bool {
        switch displayOptions {
        case .all:
            return true
        case .incomplete:
            return !reminder.isCompleted
        case .complete:
            return reminder.isCompleted
        }
    }

    private func calendarOrCreate(withName name: String, source: EKSource) -> EKCalendar {
        if let calendar = self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() }) {
            return calendar
        }

        let newCalendar = EKCalendar(for: .reminder, eventStore: Store)
        newCalendar.title = name
        newCalendar.source = source

        do {
            try Store.saveCalendar(newCalendar, commit: true)
            print("Created list '\(name)'")
            return newCalendar
        } catch let error {
            print("Failed to create list with error: \(error)")
            exit(1)
        }
    }

    private func calendar(withName name: String) -> EKCalendar {
        if let calendar = self.getCalendars().find(where: { $0.title.lowercased() == name.lowercased() }) {
            return calendar
        } else {
            print(RemsError.listNotFound(name).errorDescription!)
            exit(1)
        }
    }

    private func getCalendars() -> [EKCalendar] {
        return Store.calendars(for: .reminder)
                    .filter { $0.allowsContentModifications }
    }

    private func getReminder(from reminders: [EKReminder], at index: String) -> EKReminder? {
        precondition(!index.isEmpty, "Index cannot be empty, argument parser must be misconfigured")
        if let index = Int(index) {
            return reminders[safe: index]
        } else {
            // Exact external ID match
            if let match = reminders.first(where: { $0.calendarItemExternalIdentifier == index }) {
                return match
            }

            // ID prefix match (minimum 4 characters) with ambiguity detection
            if index.count >= 4 {
                let prefixMatches = reminders.filter {
                    $0.calendarItemExternalIdentifier.lowercased().hasPrefix(index.lowercased())
                }
                if prefixMatches.count == 1 {
                    return prefixMatches.first
                } else if prefixMatches.count > 1 {
                    print("Ambiguous identifier '\(index)' matches \(prefixMatches.count) reminders:")
                    for match in prefixMatches {
                        let id = match.calendarItemExternalIdentifier ?? ""
                        print("  \(id): \(match.title ?? "<untitled>")")
                    }
                    return nil
                }
            }

            // Title match (exact, then case-insensitive substring)
            return reminders.first { $0.title == index }
                ?? reminders.first { $0.title.localizedCaseInsensitiveContains(index) }
        }
    }

}

private func encodeToJson(data: Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    do {
        let encoded = try encoder.encode(data)
        return String(data: encoded, encoding: .utf8) ?? ""
    } catch {
        print("Failed to encode JSON: \(error)")
        exit(1)
    }
}
