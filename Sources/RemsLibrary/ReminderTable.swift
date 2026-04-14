import EventKit
import Foundation

struct ReminderTableRow {
    let values: [String]
}

enum ReminderTableColumn: String {
    case index = "IDX"
    case id = "ID"
    case list = "LIST"
    case status = "STATUS"
    case due = "DUE"
    case priority = "PRI"
    case urgency = "URG"
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
    reminder.isCompleted ? "done" : "todo"
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
    let columns: [ReminderTableColumn] = includeList
        ? [.index, .id, .list, .status, .due, .priority, .urgency, .title]
        : [.index, .id, .status, .due, .priority, .urgency, .title]

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
            case .due:
                return tableDueString(for: reminder)
            case .priority:
                return tablePriorityString(for: reminder)
            case .urgency:
                if reminder.isCompleted {
                    return "-"
                }
                return String(format: "%.1f", reminder.urgency(now: now).score)
            case .title:
                return tableTitleString(for: reminder)
            }
        }
        return ReminderTableRow(values: values)
    }

    let widths = columns.enumerated().map { offset, column in
        max(
            column.rawValue.count,
            rows.map { $0.values[offset].count }.max() ?? 0
        )
    }

    let header = columns.enumerated().map { offset, column in
        column.rawValue.padding(toLength: widths[offset], withPad: " ", startingAt: 0)
    }.joined(separator: "  ")

    let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "  ")

    let body = rows.map { row in
        row.values.enumerated().map { offset, value in
            if offset == columns.count - 1 {
                return value
            }
            return value.padding(toLength: widths[offset], withPad: " ", startingAt: 0)
        }.joined(separator: "  ")
    }

    return ([header, separator] + body).joined(separator: "\n")
}
