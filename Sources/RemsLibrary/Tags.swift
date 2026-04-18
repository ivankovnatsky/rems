import EventKit
import Foundation

private let tagRegex = try! NSRegularExpression(pattern: #"#([\w.-]+)"#)

private func isTagLine(_ line: String) -> Bool {
    let tokens = line.split(separator: " ")
    return !tokens.isEmpty && tokens.allSatisfy { $0.hasPrefix("#") && $0.count > 1 }
}

func parseTags(from notes: String?) -> [String] {
    guard let notes = notes, !notes.isEmpty else { return [] }
    var tags = [String]()
    for line in notes.components(separatedBy: .newlines).reversed() {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { continue }
        guard isTagLine(trimmed) else { break }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let matches = tagRegex.matches(in: trimmed, range: range)
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: trimmed) {
                tags.insert(String(trimmed[tagRange]), at: 0)
            }
        }
    }
    return tags
}

private func formatTag(_ tag: String) -> String {
    let cleaned = tag.hasPrefix("#") ? String(tag.dropFirst()) : tag
    return "#\(cleaned)"
}

func addTagsToNotes(existingNotes: String?, tags: [String]) -> String {
    let tagString = tags.map { formatTag($0) }.joined(separator: " ")
    guard let existing = existingNotes, !existing.isEmpty else {
        return tagString
    }
    return "\(existing)\n\(tagString)"
}

func replaceTagsInNotes(existingNotes: String?, tags: [String]) -> String {
    let stripped = stripTagsFromNotes(existingNotes)
    let tagString = tags.map { formatTag($0) }.joined(separator: " ")
    if stripped.isEmpty { return tagString }
    if tagString.isEmpty { return stripped }
    return "\(stripped)\n\(tagString)"
}

func stripTagsFromNotes(_ notes: String?) -> String {
    guard let notes = notes, !notes.isEmpty else { return "" }
    var lines = notes.components(separatedBy: .newlines)
    while let last = lines.last {
        let trimmed = last.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            lines.removeLast()
            continue
        }
        if isTagLine(trimmed) {
            lines.removeLast()
        } else {
            break
        }
    }
    return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
}

extension EKReminder {
    var reminderTags: [String] {
        return parseTags(from: self.notes)
    }
}
