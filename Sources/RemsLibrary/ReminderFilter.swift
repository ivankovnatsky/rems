import ArgumentParser
import EventKit
import Foundation

public enum ReminderFilter: String, ExpressibleByArgument, CaseIterable {
    case today
    case tomorrow
    case week
    case overdue
    case upcoming
    case completed
    case all

    public func apply(to reminders: [EKReminder], now: Date = Date(), calendar: Calendar = .current) -> [EKReminder] {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
        let startOfDayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfTomorrow

        switch self {
        case .today:
            return reminders.filter { reminder in
                guard !reminder.isCompleted else { return false }
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                let isToday = dueDate >= startOfToday && dueDate < startOfTomorrow
                let isOverdue = dueDate < startOfToday
                return isToday || isOverdue
            }
        case .tomorrow:
            return reminders.filter { reminder in
                guard !reminder.isCompleted else { return false }
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= startOfTomorrow && dueDate < startOfDayAfterTomorrow
            }
        case .week:
            let interval = calendar.dateInterval(of: .weekOfYear, for: now)
            let start = interval?.start ?? startOfToday
            let end = interval?.end ?? now
            return reminders.filter { reminder in
                guard !reminder.isCompleted else { return false }
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate >= start && dueDate < end
            }
        case .overdue:
            return reminders.filter { reminder in
                guard !reminder.isCompleted else { return false }
                guard let dueDate = reminder.dueDateComponents?.date else { return false }
                return dueDate < startOfToday
            }
        case .upcoming:
            return reminders.filter { reminder in
                !reminder.isCompleted && reminder.dueDateComponents?.date != nil
            }
        case .completed:
            return reminders.filter { $0.isCompleted }
        case .all:
            return reminders
        }
    }
}
