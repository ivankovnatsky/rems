import EventKit
import Foundation

struct ReminderUrgency: Equatable {
    let score: Double

    init(
        dueDate: Date? = nil,
        isAllDay: Bool = false,
        priority: EKReminderPriority,
        creationDate: Date? = nil,
        isCompleted: Bool = false,
        now: Date = Date()
    ) {
        let effectiveDueDate: Date?
        if let dueDate, isAllDay {
            let calendar = Calendar.current
            let startOfNextDay = calendar.date(
                byAdding: .day, value: 1, to: calendar.startOfDay(for: dueDate))
            effectiveDueDate = startOfNextDay?.addingTimeInterval(-1) ?? dueDate
        } else {
            effectiveDueDate = dueDate
        }

        let priorityWeight: Double
        switch priority {
        case .none:
            priorityWeight = 0
        case .low:
            priorityWeight = 1.5
        case .medium:
            priorityWeight = 3.0
        case .high:
            priorityWeight = 6.0
        @unknown default:
            priorityWeight = 0
        }

        let dueWeight: Double
        if let effectiveDueDate {
            let daysUntilDue = effectiveDueDate.timeIntervalSince(now) / 86_400
            switch daysUntilDue {
            case ..<0:
                dueWeight = 10 + min(abs(daysUntilDue), 30) * 0.5
            case 0..<1:
                dueWeight = 10 - (daysUntilDue * 2)
            case 1..<3:
                dueWeight = 8 - ((daysUntilDue - 1) * 1.5)
            case 3..<7:
                dueWeight = 5 - ((daysUntilDue - 3) * 0.5)
            default:
                dueWeight = max(0.25, 3 - log2(max(daysUntilDue, 1)))
            }
        } else {
            dueWeight = 0
        }

        let ageWeight: Double
        if let creationDate {
            let ageInDays = max(now.timeIntervalSince(creationDate) / 86_400, 0)
            ageWeight = min(ageInDays, 30) * 0.05
        } else {
            ageWeight = 0
        }

        let completionPenalty: Double = isCompleted ? -100 : 0
        self.score = dueWeight + priorityWeight + ageWeight + completionPenalty
    }
}

extension EKReminder {
    func urgency(now: Date = Date()) -> ReminderUrgency {
        let components = self.dueDateComponents
        let isAllDay = components != nil && components?.hour == nil
        return ReminderUrgency(
            dueDate: components?.date,
            isAllDay: isAllDay,
            priority: self.mappedPriority,
            creationDate: self.creationDate,
            isCompleted: self.isCompleted,
            now: now
        )
    }
}
