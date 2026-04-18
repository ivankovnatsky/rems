import EventKit
import Foundation

func parseTags(from notes: String?) -> [String] {
    guard let notes = notes else { return [] }
    let pattern = #"(?:^|\s)#(\w+)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(notes.startIndex..., in: notes)
    let matches = regex.matches(in: notes, range: range)
    var tags = [String]()
    for match in matches {
        if let tagRange = Range(match.range(at: 1), in: notes) {
            tags.append(String(notes[tagRange]))
        }
    }
    return tags
}

func addTagsToNotes(existingNotes: String?, tags: [String]) -> String {
    let tagString = tags.map { tag -> String in
        tag.hasPrefix("#") ? tag : "#\(tag)"
    }.joined(separator: " ")

    guard let existing = existingNotes, !existing.isEmpty else {
        return tagString
    }
    return "\(existing)\n\(tagString)"
}

func replaceTagsInNotes(existingNotes: String?, tags: [String]) -> String {
    let stripped = stripTagsFromNotes(existingNotes)
    let tagString = tags.map { tag -> String in
        tag.hasPrefix("#") ? tag : "#\(tag)"
    }.joined(separator: " ")

    if stripped.isEmpty {
        return tagString
    }
    if tagString.isEmpty {
        return stripped
    }
    return "\(stripped)\n\(tagString)"
}

func stripTagsFromNotes(_ notes: String?) -> String {
    guard let notes = notes else { return "" }
    let pattern = #"(?:^|\s)#\w+"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return notes }
    let range = NSRange(notes.startIndex..., in: notes)
    let result = regex.stringByReplacingMatches(in: notes, range: range, withTemplate: "")
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

extension EKReminder {
    var reminderTags: [String] {
        return parseTags(from: self.notes)
    }
}
