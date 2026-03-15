import ArgumentParser
import EventKit

public enum Sort: String, Decodable, ExpressibleByArgument, CaseIterable {
    case none
    case creationDate = "creation-date"
    case dueDate = "due-date"

    public static let commaSeparatedCases = Self.allCases.map { $0.rawValue }.joined(separator: ", ")

    func sortFunction(order: CustomSortOrder) -> (EKReminder, EKReminder) -> Bool {
        let comparison: (Date, Date) -> Bool = order == .ascending ? (<) : (>)
        switch self {
            case .none: return { _, _ in fatalError() }
            case .creationDate: return {
                switch ($0.creationDate, $1.creationDate) {
                    case (.none, .none): return false
                    case (.none, .some): return false
                    case (.some, .none): return true
                    case let (.some(d0), .some(d1)): return comparison(d0, d1)
                }
            }
            case .dueDate: return {
                switch ($0.dueDateComponents?.date, $1.dueDateComponents?.date) {
                    case (.none, .none): return false
                    case (.none, .some): return false
                    case (.some, .none): return true
                    case let (.some(d0), .some(d1)): return comparison(d0, d1)
                }
            }
        }
    }
}

// TODO: Replace with SortOrder when we drop < macOS 12.0
public enum CustomSortOrder: String, Decodable, ExpressibleByArgument, CaseIterable {
    case ascending
    case descending

    public static let commaSeparatedCases = Self.allCases.map { $0.rawValue }.joined(separator: ", ")
}
