import ArgumentParser
import Foundation

private let calendar = Calendar.current
private let allComponents: Set<Calendar.Component> = [
    .era, .year, .yearForWeekOfYear, .quarter, .month,
    .weekOfYear, .weekOfMonth, .weekday, .weekdayOrdinal, .day,
    .hour, .minute, .second, .nanosecond,
    .calendar, .timeZone
]
let timeComponents: Set<Calendar.Component> = [
    .hour, .minute, .second, .nanosecond,
]

func calendarComponents(except removedComponents: Set<Calendar.Component> = []) -> Set<Calendar.Component> {
    return allComponents.subtracting(removedComponents)
}

private let explicitDateFormats = [
    "yyyy-MM-dd",
    "yyyy-MM-dd HH:mm",
    "yyyy-MM-dd HH:mm:ss",
    "MM/dd/yyyy",
    "MM/dd/yyyy HH:mm",
    "dd-MM-yy",
    "dd-MM-yyyy",
]

private func parseExplicitFormat(_ string: String) -> DateComponents? {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

    // Try ISO 8601 first
    let isoWithFraction = ISO8601DateFormatter()
    isoWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoWithout = ISO8601DateFormatter()
    isoWithout.formatOptions = [.withInternetDateTime]

    if let date = isoWithFraction.date(from: trimmed) ?? isoWithout.date(from: trimmed) {
        return calendar.dateComponents(calendarComponents(), from: date)
    }

    // Try explicit date formats
    for format in explicitDateFormats {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = format
        if let date = formatter.date(from: trimmed) {
            let hasTime = format.contains("HH:mm")
            if hasTime {
                return calendar.dateComponents(calendarComponents(), from: date)
            } else {
                return calendar.dateComponents(calendarComponents(except: timeComponents), from: date)
            }
        }
    }

    return nil
}

private func components(from string: String) -> DateComponents? {
    guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
        fatalError("error: failed to create NSDataDetector")
    }

    let range = NSRange(string.startIndex..<string.endIndex, in: string)

    let matches = detector.matches(in: string, options: .anchored, range: range)
    if matches.count == 1, let match = matches.first, let date = match.date {
        var includeTime = true
        if match.responds(to: NSSelectorFromString("timeIsSignificant")) {
            includeTime = match.value(forKey: "timeIsSignificant") as? Bool ?? true
        } else {
            print("warning: timeIsSignificant is not available, please report this to ivankovnatsky/rems")
        }

        let timeZone = match.timeZone ?? .current
        let parsedComponents = calendar.dateComponents(in: timeZone, from: date)
        if includeTime {
            return parsedComponents
        } else {
            return calendar.dateComponents(calendarComponents(except: timeComponents), from: date)
        }
    }

    // Fallback to explicit date format parsing
    return parseExplicitFormat(string)
}

extension DateComponents: @retroactive ExpressibleByArgument {
      public init?(argument: String) {
          if let components = components(from: argument) {
              self = components
          } else {
              return nil
          }
      }
}
