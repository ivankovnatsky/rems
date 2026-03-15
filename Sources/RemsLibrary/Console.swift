import Foundation

enum Console {
    static var isTTY: Bool {
        isatty(STDIN_FILENO) != 0
    }

    static func confirm(_ prompt: String, defaultValue: Bool = false) -> Bool {
        guard isTTY else { return defaultValue }
        let suffix = defaultValue ? "[Y/n]" : "[y/N]"
        Swift.print("\(prompt) \(suffix)", terminator: " ")
        guard let input = Swift.readLine()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty
        else {
            return defaultValue
        }
        switch input.lowercased() {
        case "y", "yes":
            return true
        case "n", "no":
            return false
        default:
            return defaultValue
        }
    }
}
