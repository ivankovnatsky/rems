import EventKit
import Foundation

private func terminalWidth() -> Int? {
    var w = winsize()
    if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0, w.ws_col > 0 {
        return Int(w.ws_col)
    }
    return nil
}

struct ReminderTableRow {
    let values: [String]
}

enum ReminderTableColumn: String {
    case index = "IDX"
    case id = "ID"
    case list = "LIST"
    case status = "STATUS"
    case created = "CREATED"
    case done = "DONE"
    case due = "DUE"
    case priority = "PRI"
    case tags = "TAGS"
    case title = "TITLE"
}

func shortExternalID(for reminder: EKReminder) -> String {
    guard let externalID = reminder.calendarItemExternalIdentifier, !externalID.isEmpty else {
        return "-"
    }
    return String(externalID.prefix(8))
}

func tableDueString(for reminder: EKReminder) -> String {
    formattedDueDate(from: reminder) ?? "-"
}

func tablePriorityString(for reminder: EKReminder) -> String {
    switch reminder.mappedPriority {
    case .none:
        return "-"
    case .low:
        return "L"
    case .medium:
        return "M"
    case .high:
        return "H"
    @unknown default:
        return "?"
    }
}

func tableStatusString(for reminder: EKReminder) -> String {
    reminder.isCompleted ? "completed" : "-"
}

private let relativeDateFormatter = RelativeDateTimeFormatter()

func tableCompletedString(for reminder: EKReminder) -> String {
    guard let date = reminder.completionDate else { return "-" }
    return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
}

func tableCreatedString(for reminder: EKReminder) -> String {
    guard let date = reminder.creationDate else { return "-" }
    return relativeDateFormatter.localizedString(for: date, relativeTo: Date())
}

func tableTagsString(for reminder: EKReminder) -> String {
    let tags = reminder.reminderTags
    if tags.isEmpty { return "-" }
    return tags.map { "#\($0)" }.joined(separator: " ")
}

func tableTitleString(for reminder: EKReminder) -> String {
    let title = reminder.title ?? "<unknown>"
    guard let notes = reminder.notes, !notes.isEmpty else {
        return title
    }
    let flattened = notes
        .replacingOccurrences(of: "\r\n", with: " ")
        .replacingOccurrences(of: "\n", with: " ")
        .replacingOccurrences(of: "\r", with: " ")
    return "\(title) [\(flattened)]"
}

func makeTable(
    reminders: [(reminder: EKReminder, index: Int?, listName: String?)],
    includeList: Bool,
    now: Date = Date()
) -> String {
    let hasCompleted = reminders.contains { $0.reminder.isCompleted }
    let hasTags = reminders.contains { !$0.reminder.reminderTags.isEmpty }
    var columns: [ReminderTableColumn] = includeList
        ? [.index, .id, .list, .status, .created, .due, .priority, .title]
        : [.index, .id, .status, .created, .due, .priority, .title]
    if hasCompleted, let statusIdx = columns.firstIndex(of: .status) {
        columns.insert(.done, at: statusIdx + 1)
    }
    if hasTags, let priIdx = columns.firstIndex(of: .priority) {
        columns.insert(.tags, at: priIdx + 1)
    }

    let rows = reminders.map { entry in
        let reminder = entry.reminder
        let values = columns.map { column -> String in
            switch column {
            case .index:
                return entry.index.map(String.init) ?? "-"
            case .id:
                return shortExternalID(for: reminder)
            case .list:
                return entry.listName ?? reminder.calendar.title
            case .status:
                return tableStatusString(for: reminder)
            case .created:
                return tableCreatedString(for: reminder)
            case .done:
                return tableCompletedString(for: reminder)
            case .due:
                return tableDueString(for: reminder)
            case .priority:
                return tablePriorityString(for: reminder)
            case .tags:
                return tableTagsString(for: reminder)
            case .title:
                return tableTitleString(for: reminder)
            }
        }
        return ReminderTableRow(values: values)
    }

    var widths = columns.enumerated().map { offset, column in
        max(
            column.rawValue.count,
            rows.map { $0.values[offset].count }.max() ?? 0
        )
    }

    let titleIndex = columns.count - 1
    if let termWidth = terminalWidth() {
        let nonTitleWidth = widths.dropLast().reduce(0, +) + (columns.count - 1) * 2
        let maxTitleWidth = max(columns[titleIndex].rawValue.count, termWidth - nonTitleWidth)
        widths[titleIndex] = min(widths[titleIndex], maxTitleWidth)
    }

    let truncate = { (s: String, maxLen: Int) -> String in
        guard s.count > maxLen, maxLen > 1 else { return s }
        return String(s.prefix(maxLen - 1)) + "…"
    }

    let header = columns.enumerated().map { offset, column in
        column.rawValue.padding(toLength: widths[offset], withPad: " ", startingAt: 0)
    }.joined(separator: "  ")

    let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")

    let body = rows.map { row in
        row.values.enumerated().map { offset, value in
            let val = offset == titleIndex ? truncate(value, widths[offset]) : value
            if offset == columns.count - 1 {
                return val
            }
            return val.padding(toLength: widths[offset], withPad: " ", startingAt: 0)
        }.joined(separator: "  ")
    }

    return ([header, separator] + body).joined(separator: "\n")
}
