import Foundation
@testable import RemsLibrary
import XCTest

final class NaturalLanguageTests: XCTestCase {
    func testYesterday() throws {
        let components = try XCTUnwrap(DateComponents(argument: "yesterday"))
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))

        XCTAssertNil(components.hour)
        let date = try XCTUnwrap(components.date)
        XCTAssertTrue(Calendar.current.isDate(date, inSameDayAs: yesterday))
    }

    func testTodayString() throws {
        let components = try XCTUnwrap(DateComponents(argument: "today"))

        XCTAssertNil(components.hour)
        let date = try XCTUnwrap(components.date)
        XCTAssertTrue(Calendar.current.isDateInToday(date))
    }

    func testTodayNoon() throws {
        let components = try XCTUnwrap(DateComponents(argument: "12:00"))

        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 0)
        let date = try XCTUnwrap(components.date)
        XCTAssertTrue(Calendar.current.isDateInToday(date))
    }

    func testTonight() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tonight"))

        XCTAssertNotNil(components.hour)
        let date = try XCTUnwrap(components.date)
        XCTAssertTrue(Calendar.current.isDateInToday(date))
    }

    func testTomorrow() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tomorrow"))
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))

        XCTAssertNil(components.hour)
        let date = try XCTUnwrap(components.date)
        XCTAssertTrue(Calendar.current.isDate(date, inSameDayAs: tomorrow))
    }

    func testTomorrowAtTime() throws {
        let components = try XCTUnwrap(DateComponents(argument: "tomorrow 9pm"))
        let tomorrow = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: Date()))

        XCTAssertEqual(components.hour, 21)
        XCTAssertEqual(components.minute, 0)
        let date = try XCTUnwrap(components.date)
        XCTAssertTrue(Calendar.current.isDate(date, inSameDayAs: tomorrow))
    }

    func testRelativeDayCount() throws {
        let components = try XCTUnwrap(DateComponents(argument: "in 2 days"))
        let twoDays = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 2, to: Date()))

        XCTAssertNil(components.hour)
        let date = try XCTUnwrap(components.date)
        XCTAssertTrue(Calendar.current.isDate(date, inSameDayAs: twoDays))
    }

    func testNextSaturday() throws {
        let components = try XCTUnwrap(DateComponents(argument: "next saturday"))
        let date = try XCTUnwrap(Calendar.current.date(from: components))

        XCTAssertTrue(Calendar.current.isDateInWeekend(date))
    }

    // FB8921206
    func testNextWeekend() throws {
        // TODO: This should be inverted but DataDetector doesn't support it right now
        XCTAssertNil(DateComponents(argument: "next weekend"))
    }

    func testSpecificDays() throws {
        XCTAssertNotNil(DateComponents(argument: "next monday"))
        XCTAssertNotNil(DateComponents(argument: "on monday at 9pm"))
    }

    func testIgnoreRandomString() {
        XCTAssertNil(DateComponents(argument: "blah tomorrow 9pm"))
    }
}
