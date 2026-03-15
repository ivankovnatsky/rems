import ArgumentParser
import EventKit

public enum Recurrence: String, ExpressibleByArgument, CaseIterable {
    case daily
    case weekdays
    case weekends
    case weekly
    case biweekly
    case monthly
    case every3Months = "every-3-months"
    case every6Months = "every-6-months"
    case yearly

    var recurrenceRule: EKRecurrenceRule {
        switch self {
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekdays:
            let days = [EKRecurrenceDayOfWeek(.monday), EKRecurrenceDayOfWeek(.tuesday),
                        EKRecurrenceDayOfWeek(.wednesday), EKRecurrenceDayOfWeek(.thursday),
                        EKRecurrenceDayOfWeek(.friday)]
            return EKRecurrenceRule(
                recurrenceWith: .weekly, interval: 1,
                daysOfTheWeek: days, daysOfTheMonth: nil,
                monthsOfTheYear: nil, weeksOfTheYear: nil,
                daysOfTheYear: nil, setPositions: nil, end: nil)
        case .weekends:
            let days = [EKRecurrenceDayOfWeek(.saturday), EKRecurrenceDayOfWeek(.sunday)]
            return EKRecurrenceRule(
                recurrenceWith: .weekly, interval: 1,
                daysOfTheWeek: days, daysOfTheMonth: nil,
                monthsOfTheYear: nil, weeksOfTheYear: nil,
                daysOfTheYear: nil, setPositions: nil, end: nil)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .biweekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 2, end: nil)
        case .monthly:
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .every3Months:
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 3, end: nil)
        case .every6Months:
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 6, end: nil)
        case .yearly:
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
    }
}
