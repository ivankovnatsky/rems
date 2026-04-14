import EventKit
import Foundation
@testable import RemsLibrary
import XCTest

final class ReminderUrgencyTests: XCTestCase {
    func testOverdueHighPriorityBeatsFutureLowPriority() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-04-12T12:00:00Z"))

        let overdue = ReminderUrgency(
            dueDate: now.addingTimeInterval(-86_400),
            priority: .high,
            creationDate: now.addingTimeInterval(-7 * 86_400),
            now: now
        )

        let future = ReminderUrgency(
            dueDate: now.addingTimeInterval(7 * 86_400),
            priority: .low,
            creationDate: now.addingTimeInterval(-7 * 86_400),
            now: now
        )

        XCTAssertGreaterThan(overdue.score, future.score)
    }

    func testHigherPriorityRaisesUrgencyForUndatedReminder() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-04-12T12:00:00Z"))

        let low = ReminderUrgency(priority: .low, creationDate: now, now: now)
        let high = ReminderUrgency(priority: .high, creationDate: now, now: now)

        XCTAssertGreaterThan(high.score, low.score)
    }

    func testAllDayReminderStaysDueTodayUntilEndOfDay() throws {
        let calendar = Calendar.current
        let startOfDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 4, day: 14)))
        let midday = startOfDay.addingTimeInterval(12 * 3_600)
        let almostMidnight = startOfDay.addingTimeInterval(86_400 - 60)
        let nextDay = startOfDay.addingTimeInterval(86_400 + 60)

        let middayScore = ReminderUrgency(
            dueDate: startOfDay, isAllDay: true, priority: .none, now: midday
        ).score
        let lateScore = ReminderUrgency(
            dueDate: startOfDay, isAllDay: true, priority: .none, now: almostMidnight
        ).score
        let overdueScore = ReminderUrgency(
            dueDate: startOfDay, isAllDay: true, priority: .none, now: nextDay
        ).score

        // Still in the "due today" band for the whole day
        XCTAssertGreaterThanOrEqual(middayScore, 9.0)
        XCTAssertLessThan(middayScore, 11.0)
        XCTAssertGreaterThanOrEqual(lateScore, 9.0)
        XCTAssertLessThan(lateScore, 11.0)
        // Only after the day ends does it tip into overdue
        XCTAssertGreaterThan(overdueScore, lateScore)
    }

    func testCompletedReminderGetsHeavyPenalty() throws {
        let now = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-04-12T12:00:00Z"))

        let pending = ReminderUrgency(
            dueDate: now.addingTimeInterval(3_600),
            priority: .medium,
            creationDate: now.addingTimeInterval(-86_400),
            isCompleted: false,
            now: now
        )

        let completed = ReminderUrgency(
            dueDate: now.addingTimeInterval(3_600),
            priority: .medium,
            creationDate: now.addingTimeInterval(-86_400),
            isCompleted: true,
            now: now
        )

        XCTAssertLessThan(completed.score, pending.score)
    }
}
