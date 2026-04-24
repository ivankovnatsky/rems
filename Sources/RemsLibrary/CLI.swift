import ArgumentParser
import EventKit
import Foundation

private let reminders = Reminders()

protocol SkipsAccessRequest {}

private struct Lists: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage reminder lists",
        subcommands: [
            Lists.Show.self,
            Lists.New.self,
            Lists.Delete.self,
            Lists.Clean.self,
            Lists.Rename.self,
        ]
    )

    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Print the name of lists")
        @Option(
            name: .shortAndLong,
            help: "Output format: plain, table, json, tsv, or quiet")
        var format: OutputFormat = .plain

        func run() {
            reminders.showLists(outputFormat: format)
        }
    }

    struct New: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new list")

        @Argument(
            help: "The name of the new list")
        var listName: String

        @Option(
            name: .shortAndLong,
            help: "The name of the source of the list, if all your lists use the same source it will default to that")
        var source: String?

        func run() {
            reminders.newList(with: self.listName, source: self.source)
        }
    }

    struct Delete: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a list")

        @Argument(
            help: "The name of the list to delete, see 'lists' for names",
            completion: .custom(listNameCompletion))
        var listName: String

        @Flag(
            name: .shortAndLong,
            help: "Skip confirmation prompt")
        var force = false

        @Flag(
            help: "Delete the list even if it has items")
        var deleteItems = false

        func run() {
            reminders.deleteList(withName: self.listName, force: self.force, deleteItems: self.deleteItems)
        }
    }

    struct Clean: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete all empty lists")

        @Flag(
            name: .shortAndLong,
            help: "Skip confirmation prompt")
        var force = false

        @Flag(
            name: [.customShort("n"), .customLong("dry-run")],
            help: "Preview the action without making changes")
        var dryRun = false

        func run() {
            reminders.purgeLists(force: force, dryRun: dryRun)
        }
    }

    struct Rename: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Rename a list")

        @Argument(
            help: "The current name of the list",
            completion: .custom(listNameCompletion))
        var listName: String

        @Argument(
            help: "The new name for the list")
        var newName: String

        func run() {
            reminders.renameList(oldName: self.listName, newName: self.newName)
        }
    }
}

private struct Show: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print reminders, optionally filtered by list")

    @Argument(
        help: "The list to print items from, see 'lists' for names. Omit to show all reminders",
        completion: .custom(listNameCompletion))
    var listName: String?

    @Option(
        name: .long,
        help: "Filter reminders: today, tomorrow, week, overdue, upcoming, completed, or all")
    var filter: ReminderFilter?

    @Flag(help: "Show completed items only")
    var onlyCompleted = false

    @Flag(help: "Include completed items in output")
    var includeCompleted = false

    @Flag(help: "When using --due-date, also include items due before the due date")
    var includeOverdue = false

    @Option(
        name: .shortAndLong,
        help: "Show the reminders in a specific order, one of: \(Sort.commaSeparatedCases)")
    var sort: Sort = .none

    @Option(
        name: [.customShort("o"), .long],
        help: "How the sort order should be applied, one of: \(CustomSortOrder.commaSeparatedCases)")
    var sortOrder: CustomSortOrder?

    @Option(
        name: .shortAndLong,
        help: "Show only reminders due on this date")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "Output format: plain, table, json, tsv, or quiet")
    var format: OutputFormat = .plain

    func validate() throws {
        if self.onlyCompleted && self.includeCompleted {
            throw ValidationError(
                "Cannot specify both --show-completed and --only-completed")
        }
        if self.filter != nil && self.listName != nil {
            throw ValidationError(
                "Cannot use --filter with a specific list")
        }
        if self.filter != nil && (self.onlyCompleted || self.includeCompleted) {
            throw ValidationError(
                "Cannot use --filter with --only-completed or --include-completed")
        }
    }

    func run() {
        let resolvedSortOrder = self.sortOrder ?? sort.defaultOrder

        if let listName = self.listName {
            var displayOptions = DisplayOptions.incomplete
            if self.onlyCompleted {
                displayOptions = .complete
            } else if self.includeCompleted {
                displayOptions = .all
            }

            reminders.showListItems(
                withName: listName, dueOn: self.dueDate, includeOverdue: self.includeOverdue,
                displayOptions: displayOptions, outputFormat: format,
                sort: sort, sortOrder: resolvedSortOrder)
        } else {
            var displayOptions = DisplayOptions.incomplete
            if self.filter != nil {
                displayOptions = .all
            } else if self.onlyCompleted {
                displayOptions = .complete
            } else if self.includeCompleted {
                displayOptions = .all
            }

            reminders.showAllReminders(
                dueOn: self.dueDate, includeOverdue: self.includeOverdue,
                displayOptions: displayOptions, outputFormat: format,
                filter: self.filter,
                sort: sort, sortOrder: resolvedSortOrder)
        }
    }
}

private struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a reminder to a list")

    @Argument(
        help: "The list to add to, see 'lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        parsing: .remaining,
        help: "The reminder contents")
    var reminder: [String]

    @Option(
        name: .shortAndLong,
        help: "The date the reminder is due")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "The priority of the reminder")
    var priority: Priority = .none

    @Option(
        name: .shortAndLong,
        help: "Output format: plain, table, json, tsv, or quiet")
    var format: OutputFormat = .plain

    @Option(
        name: .shortAndLong,
        help: "The notes to add to the reminder")
    var notes: String?

    @Option(
        name: [.customLong("repeat"), .customShort("r")],
        help: "The recurrence interval, one of: \(Recurrence.commaSeparatedCases)")
    var recurrence: Recurrence?

    @Flag(name: .shortAndLong, help: "Create the list if it doesn't exist")
    var create = false

    func run() {
        reminders.addReminder(
            string: self.reminder.joined(separator: " "),
            notes: self.notes,
            toListNamed: self.listName,
            dueDateComponents: self.dueDate,
            priority: priority,
            recurrence: recurrence,
            createList: create,
            outputFormat: format)
    }
}

private struct Complete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Complete one or more reminders")

    @Argument(
        help: "The list to complete a reminder on, see 'lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index(es), id(s), or title(s) of the reminders, see 'show' for indexes")
    var indexes: [String]

    @Option(
        name: .long,
        help: "The completion date to set on the reminder")
    var completionDate: DateComponents?

    @Flag(
        name: [.customShort("n"), .customLong("dry-run")],
        help: "Preview the action without making changes")
    var dryRun = false

    func run() {
        reminders.setComplete(true, itemsAtIndexes: self.indexes, onListNamed: self.listName, completionDate: self.completionDate?.date, dryRun: self.dryRun)
    }
}

private struct Uncomplete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Uncomplete one or more reminders")

    @Argument(
        help: "The list to uncomplete a reminder on, see 'lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index(es), id(s), or title(s) of the reminders, see 'show' for indexes")
    var indexes: [String]

    @Flag(
        name: [.customShort("n"), .customLong("dry-run")],
        help: "Preview the action without making changes")
    var dryRun = false

    func run() {
        reminders.setComplete(false, itemsAtIndexes: self.indexes, onListNamed: self.listName, dryRun: self.dryRun)
    }
}

private struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Delete a reminder")

    @Argument(
        help: "The list to delete a reminder on, see 'lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index, id, or title of the reminder, see 'show' for indexes")
    var index: String

    @Flag(help: "Show completed items only")
    var onlyCompleted = false

    @Flag(help: "Include completed items in output")
    var includeCompleted = false

    @Flag(
        name: [.customShort("n"), .customLong("dry-run")],
        help: "Preview the action without making changes")
    var dryRun = false

    @Flag(
        name: .shortAndLong,
        help: "Skip confirmation prompt")
    var force = false

    func validate() throws {
        if self.onlyCompleted && self.includeCompleted {
            throw ValidationError(
                "Cannot specify both --show-completed and --only-completed")
        }
    }

    func run() {
        var displayOptions = DisplayOptions.incomplete
        if self.onlyCompleted {
            displayOptions = .complete
        } else if self.includeCompleted {
            displayOptions = .all
        }

        reminders.delete(itemAtIndex: self.index, onListNamed: self.listName, displayOptions: displayOptions, dryRun: self.dryRun, force: self.force)
    }
}

func listNameCompletion(_ arguments: [String]) -> [String] {
    return reminders.getListNames().map { $0.replacingOccurrences(of: ":", with: "\\:") }
}

private struct Edit: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Edit the text of a reminder")

    @Argument(
        help: "The list to edit a reminder on, see 'lists' for names",
        completion: .custom(listNameCompletion))
    var listName: String

    @Argument(
        help: "The index, id, or title of the reminder, see 'show' for indexes")
    var index: String

    @Option(
        name: .long,
        help: "The notes to set on the reminder, overwriting previous notes")
    var notes: String?

    @Option(
        name: .shortAndLong,
        help: "The due date to set on the reminder")
    var dueDate: DateComponents?

    @Option(
        name: .shortAndLong,
        help: "The priority to set on the reminder")
    var priority: Priority?

    @Option(
        name: [.customLong("repeat"), .customShort("r")],
        help: "The recurrence interval, one of: \(Recurrence.commaSeparatedCases)")
    var recurrence: Recurrence?

    @Option(
        name: .long,
        help: "The completion date to set on the reminder")
    var completionDate: DateComponents?

    @Flag(help: "Clear the due date on the reminder")
    var clearDueDate = false

    @Flag(help: "Show completed items only")
    var onlyCompleted = false

    @Flag(help: "Include completed items in output")
    var includeCompleted = false

    @Flag(
        name: [.customShort("n"), .customLong("dry-run")],
        help: "Preview the action without making changes")
    var dryRun = false

    @Argument(
        parsing: .remaining,
        help: "The new reminder contents")
    var reminder: [String] = []

    func validate() throws {
        if self.reminder.isEmpty && self.notes == nil && self.dueDate == nil && self.priority == nil && self.recurrence == nil && self.completionDate == nil && !self.clearDueDate {
            throw ValidationError("Must specify either new reminder content, notes, due date, clear due date, priority, repeat, or completion date")
        }
        if self.dueDate != nil && self.clearDueDate {
            throw ValidationError("Cannot specify both --due-date and --clear-due-date")
        }
        if self.onlyCompleted && self.includeCompleted {
            throw ValidationError(
                "Cannot specify both --show-completed and --only-completed")
        }
    }

    func run() {
        var displayOptions = DisplayOptions.incomplete
        if self.onlyCompleted {
            displayOptions = .complete
        } else if self.includeCompleted {
            displayOptions = .all
        }

        let newText = self.reminder.joined(separator: " ")
        reminders.edit(
            itemAtIndex: self.index,
            onListNamed: self.listName,
            newText: newText.isEmpty ? nil : newText,
            newNotes: self.notes,
            newDueDate: self.dueDate,
            clearDueDate: self.clearDueDate,
            newPriority: self.priority,
            newRecurrence: self.recurrence,
            newCompletionDate: self.completionDate?.date,
            displayOptions: displayOptions,
            dryRun: self.dryRun
        )
    }
}

private struct Move: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Move a reminder to a different list")

    @Argument(
        help: "The list to move a reminder from, see 'lists' for names",
        completion: .custom(listNameCompletion))
    var fromListName: String

    @Argument(
        help: "The index, id, or title of the reminder to move, see 'show' for indexes")
    var index: String

    @Argument(
        help: "The list to move the reminder to, see 'lists' for names",
        completion: .custom(listNameCompletion))
    var toListName: String

    @Flag(name: .shortAndLong, help: "Create the destination list if it doesn't exist")
    var create = false

    @Flag(help: "Show completed items only")
    var onlyCompleted = false

    @Flag(help: "Include completed items in output")
    var includeCompleted = false

    @Flag(
        name: [.customShort("n"), .customLong("dry-run")],
        help: "Preview the action without making changes")
    var dryRun = false

    func validate() throws {
        if self.onlyCompleted && self.includeCompleted {
            throw ValidationError(
                "Cannot specify both --show-completed and --only-completed")
        }
    }

    func run() {
        var displayOptions = DisplayOptions.incomplete
        if self.onlyCompleted {
            displayOptions = .complete
        } else if self.includeCompleted {
            displayOptions = .all
        }

        reminders.move(
            itemAtIndex: self.index,
            fromListNamed: self.fromListName,
            toListNamed: self.toListName,
            createList: self.create,
            displayOptions: displayOptions,
            dryRun: self.dryRun)
    }
}


private struct Auth: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage Reminders authorization",
        subcommands: [
            Auth.Status.self,
            Auth.Request.self,
        ]
    )

    struct Status: ParsableCommand, SkipsAccessRequest {
        static let configuration = CommandConfiguration(
            abstract: "Show Reminders authorization status")

        func run() {
            printAuthorizationStatus()
        }
    }

    struct Request: ParsableCommand, SkipsAccessRequest {
        static let configuration = CommandConfiguration(
            abstract: "Request Reminders access")

        func run() {
            let current = EKEventStore.authorizationStatus(for: .reminder)
            if current == .notDetermined {
                let (granted, error) = Reminders.requestAccess()
                printAuthorizationStatus()
                if !granted {
                    if let error = error {
                        print("error: \(error.localizedDescription)")
                    }
                    Darwin.exit(1)
                }
            } else {
                printAuthorizationStatus()
                if current == .denied || current == .restricted {
                    Darwin.exit(1)
                }
            }
        }
    }
}

private func printAuthorizationStatus() {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    switch status {
    case .notDetermined:
        print("not-determined")
    case .restricted:
        print("restricted")
    case .denied:
        print("denied")
        print("Grant access in System Settings > Privacy & Security > Reminders")
    case .fullAccess:
        print("full-access")
    case .writeOnly:
        print("write-only")
        print("Grant full access in System Settings > Privacy & Security > Reminders")
    case .authorized:
        print("authorized")
    @unknown default:
        print("unknown")
    }
}

public struct CLI: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "rems",
        abstract: "Interact with macOS Reminders from the command line",
        subcommands: [
            Add.self,
            Auth.self,
            Complete.self,
            Uncomplete.self,
            Delete.self,
            Edit.self,
            Lists.self,
            Move.self,
            Show.self,
        ]
    )

    public init() {}

    public static func commandSkipsAccess(_ command: ParsableCommand) -> Bool {
        return command is SkipsAccessRequest
    }
}
