import EventKit

private struct EncodableRecurrenceRule: Encodable {
    let frequency: String
    let interval: Int
    let firstDayOfTheWeek: Int
    let calendarIdentifier: String
    let daysOfTheWeek: [EncodableDayOfWeek]?
    let daysOfTheMonth: [Int]?
    let monthsOfTheYear: [Int]?
    let weeksOfTheYear: [Int]?
    let daysOfTheYear: [Int]?
    let setPositions: [Int]?
    let endDate: String?
    let occurrenceCount: Int?

    init(from rule: EKRecurrenceRule, formatter: (Date?) -> String?) {
        switch rule.frequency {
        case .daily: self.frequency = "daily"
        case .weekly: self.frequency = "weekly"
        case .monthly: self.frequency = "monthly"
        case .yearly: self.frequency = "yearly"
        @unknown default: self.frequency = "unknown"
        }
        self.interval = rule.interval
        self.firstDayOfTheWeek = rule.firstDayOfTheWeek
        self.calendarIdentifier = rule.calendarIdentifier
        self.daysOfTheWeek = rule.daysOfTheWeek?.map { EncodableDayOfWeek(from: $0) }
        self.daysOfTheMonth = rule.daysOfTheMonth?.map { $0.intValue }
        self.monthsOfTheYear = rule.monthsOfTheYear?.map { $0.intValue }
        self.weeksOfTheYear = rule.weeksOfTheYear?.map { $0.intValue }
        self.daysOfTheYear = rule.daysOfTheYear?.map { $0.intValue }
        self.setPositions = rule.setPositions?.map { $0.intValue }
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                self.endDate = formatter(endDate)
                self.occurrenceCount = nil
            } else {
                self.endDate = nil
                self.occurrenceCount = end.occurrenceCount > 0 ? end.occurrenceCount : nil
            }
        } else {
            self.endDate = nil
            self.occurrenceCount = nil
        }
    }
}

private struct EncodableDayOfWeek: Encodable {
    let dayOfTheWeek: String
    let weekNumber: Int

    init(from day: EKRecurrenceDayOfWeek) {
        switch day.dayOfTheWeek {
        case .monday: self.dayOfTheWeek = "monday"
        case .tuesday: self.dayOfTheWeek = "tuesday"
        case .wednesday: self.dayOfTheWeek = "wednesday"
        case .thursday: self.dayOfTheWeek = "thursday"
        case .friday: self.dayOfTheWeek = "friday"
        case .saturday: self.dayOfTheWeek = "saturday"
        case .sunday: self.dayOfTheWeek = "sunday"
        @unknown default: self.dayOfTheWeek = "unknown"
        }
        self.weekNumber = day.weekNumber
    }
}

private struct EncodableAlarm: Encodable {
    let type: String
    let absoluteDate: String?
    let relativeOffset: Double?
    let proximity: String?
    let structuredLocation: EncodableLocation?
    let emailAddress: String?
    let soundName: String?

    init(from alarm: EKAlarm, formatter: (Date?) -> String?) {
        switch alarm.type {
        case .display: self.type = "display"
        case .audio: self.type = "audio"
        case .procedure: self.type = "procedure"
        case .email: self.type = "email"
        @unknown default: self.type = "unknown"
        }
        self.absoluteDate = formatter(alarm.absoluteDate)
        self.relativeOffset = alarm.absoluteDate == nil ? alarm.relativeOffset : nil
        self.emailAddress = alarm.emailAddress
        self.soundName = alarm.soundName
        if let loc = alarm.structuredLocation {
            self.structuredLocation = EncodableLocation(from: loc)
            switch alarm.proximity {
            case .enter: self.proximity = "enter"
            case .leave: self.proximity = "leave"
            case .none: self.proximity = "none"
            @unknown default: self.proximity = "unknown"
            }
        } else {
            self.structuredLocation = nil
            self.proximity = nil
        }
    }
}

private struct EncodableLocation: Encodable {
    let title: String?
    let latitude: Double?
    let longitude: Double?
    let radius: Double

    init(from location: EKStructuredLocation) {
        self.title = location.title
        self.radius = location.radius
        if let geo = location.geoLocation {
            self.latitude = geo.coordinate.latitude
            self.longitude = geo.coordinate.longitude
        } else {
            self.latitude = nil
            self.longitude = nil
        }
    }
}

private struct EncodableParticipant: Encodable {
    let name: String?
    let url: String
    let status: String
    let role: String
    let type: String
    let isCurrentUser: Bool

    init(from participant: EKParticipant) {
        self.name = participant.name
        self.url = participant.url.absoluteString
        self.isCurrentUser = participant.isCurrentUser
        switch participant.participantStatus {
        case .unknown: self.status = "unknown"
        case .pending: self.status = "pending"
        case .accepted: self.status = "accepted"
        case .declined: self.status = "declined"
        case .tentative: self.status = "tentative"
        case .delegated: self.status = "delegated"
        case .completed: self.status = "completed"
        case .inProcess: self.status = "inProcess"
        @unknown default: self.status = "unknown"
        }
        switch participant.participantRole {
        case .unknown: self.role = "unknown"
        case .required: self.role = "required"
        case .optional: self.role = "optional"
        case .chair: self.role = "chair"
        case .nonParticipant: self.role = "nonParticipant"
        @unknown default: self.role = "unknown"
        }
        switch participant.participantType {
        case .unknown: self.type = "unknown"
        case .person: self.type = "person"
        case .room: self.type = "room"
        case .resource: self.type = "resource"
        case .group: self.type = "group"
        @unknown default: self.type = "unknown"
        }
    }
}

extension EKReminder: @retroactive Encodable {
    private enum EncodingKeys: String, CodingKey {
        case calendarItemIdentifier
        case externalId
        case lastModified
        case creationDate
        case title
        case notes
        case url
        case location
        case locationTitle
        case isCompleted
        case completionDate
        case priority
        case startDate
        case dueDate
        case list
        case timeZone
        case recurrence
        case recurrenceRules
        case alarms
        case attendees
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingKeys.self)

        // Identifiers
        try container.encode(self.calendarItemIdentifier, forKey: .calendarItemIdentifier)
        try container.encode(self.calendarItemExternalIdentifier, forKey: .externalId)

        // Core fields
        try container.encode(self.title, forKey: .title)
        try container.encode(self.calendar.title, forKey: .list)
        try container.encode(self.isCompleted, forKey: .isCompleted)
        try container.encode(self.priority, forKey: .priority)
        try container.encodeIfPresent(self.notes, forKey: .notes)

        // FIXME: HACK — EKCalendarItem.url is broken and always returns nil.
        // Fall back to reading the URL from Reminders' private SQLite database.
        // See: https://developer.apple.com/forums/thread/128140
        // TODO: Remove this fallback when Apple fixes the EventKit url property.
        let resolvedURL: URL? = self.url
            ?? ReminderURLLookup.cachedURLs[self.calendarItemExternalIdentifier]
        try container.encodeIfPresent(resolvedURL, forKey: .url)

        // Location (plain string from EKCalendarItem)
        try container.encodeIfPresent(self.location, forKey: .location)

        // Location from first alarm's structured location (backward compat)
        for alarm in self.alarms ?? [] {
            if let location = alarm.structuredLocation {
                try container.encodeIfPresent(location.title, forKey: .locationTitle)
                break
            }
        }

        // Dates
        try container.encodeIfPresent(format(self.completionDate), forKey: .completionDate)

        if let startDateComponents = self.startDateComponents {
            try container.encodeIfPresent(format(startDateComponents.date), forKey: .startDate)
        }

        if let dueDateComponents = self.dueDateComponents {
            try container.encodeIfPresent(format(dueDateComponents.date), forKey: .dueDate)
        }

        if let lastModifiedDate = self.lastModifiedDate {
            try container.encode(format(lastModifiedDate), forKey: .lastModified)
        }

        if let creationDate = self.creationDate {
            try container.encode(format(creationDate), forKey: .creationDate)
        }

        // Time zone
        if let tz = self.timeZone {
            try container.encode(tz.identifier, forKey: .timeZone)
        }

        // Recurrence (backward-compatible string + structured rules)
        if let rules = self.recurrenceRules, let rule = rules.first {
            try container.encode(formatRecurrence(rule), forKey: .recurrence)
            let encodableRules = rules.map { EncodableRecurrenceRule(from: $0, formatter: format) }
            try container.encode(encodableRules, forKey: .recurrenceRules)
        }

        // Alarms (all, with full detail)
        if let alarms = self.alarms, !alarms.isEmpty {
            let encodableAlarms = alarms.map { EncodableAlarm(from: $0, formatter: format) }
            try container.encode(encodableAlarms, forKey: .alarms)
        }

        // Attendees
        if let attendees = self.attendees, !attendees.isEmpty {
            let encodableAttendees = attendees.map { EncodableParticipant(from: $0) }
            try container.encode(encodableAttendees, forKey: .attendees)
        }
    }

    private func formatRecurrence(_ rule: EKRecurrenceRule) -> String {
        let frequency: String
        switch rule.frequency {
        case .daily: frequency = "daily"
        case .weekly: frequency = "weekly"
        case .monthly: frequency = "monthly"
        case .yearly: frequency = "yearly"
        @unknown default: frequency = "unknown"
        }

        if let days = rule.daysOfTheWeek, !days.isEmpty {
            let dayNames = days.map { day -> String in
                switch day.dayOfTheWeek {
                case .monday: return "Mon"
                case .tuesday: return "Tue"
                case .wednesday: return "Wed"
                case .thursday: return "Thu"
                case .friday: return "Fri"
                case .saturday: return "Sat"
                case .sunday: return "Sun"
                @unknown default: return "?"
                }
            }
            return "every \(dayNames.joined(separator: ", "))"
        }

        if rule.interval == 1 {
            return frequency
        }

        let unit: String
        switch rule.frequency {
        case .daily: unit = "days"
        case .weekly: unit = "weeks"
        case .monthly: unit = "months"
        case .yearly: unit = "years"
        @unknown default: unit = "units"
        }
        return "every \(rule.interval) \(unit)"
    }

    private func format(_ date: Date?) -> String? {
        if #available(macOS 12.0, *) {
            return date?.ISO8601Format()
        } else {
            return date?.description(with: .current)
        }
    }
}
