# rems

A command-line tool for macOS Reminders.

Started as improvements to [keith/reminders-cli](https://github.com/keith/reminders-cli)
for personal use, later incorporating ideas from [steipete/remindctl](https://github.com/steipete/remindctl).

## Features

- Natural language date parsing ("tomorrow 9am", "next monday", "in 2 days") with ISO 8601 and explicit format fallback
- Recurrence support (daily, weekly, biweekly, monthly, yearly, weekdays, weekends, every-3-months, every-6-months)
- Smart filters: today, tomorrow, week, overdue, upcoming, completed
- Reminder lookup by index, title, external ID, or ID prefix (with ambiguity detection)
- Multiple output formats: plain, table, JSON, TSV, quiet
- Table format with dynamic columns (IDX, LIST, STATUS, CREATED, DONE, DUE, PRI, TITLE) and terminal-width-aware truncation
- Smart output: title truncation disabled when piped to other commands
- Batch complete/uncomplete multiple reminders at once
- Dry-run mode for previewing changes
- Confirmation prompts on delete with `--force` to skip
- List management: create, delete, rename, clean empty lists
- Default list protection (prevents accidental deletion)
- Move reminders between lists
- Sort by creation date, due date, or urgency
- Priority levels (low, medium, high)
- Permission management: status check and access request

## Installation

### Build from source

```console
swift build --configuration release
cp .build/release/rems /usr/local/bin/
```

## Usage

```console
# Show all lists
rems lists show

# Show reminders on a list
rems show MyList

# Show a Taskwarrior-like table sorted by urgency
rems show MyList --format table --sort urgency

# Show all reminders across lists
rems show

# Show all reminders in a cross-list table
rems show --format table --sort urgency

# Filter reminders (today, tomorrow, week, overdue, upcoming, completed, all)
rems show --filter today
rems show --filter overdue
rems show --filter upcoming

# Add a reminder
rems add MyList Buy milk --due-date tomorrow --priority high

# Add with recurrence
rems add MyList "Take vitamins" --due-date "tomorrow 9am" --repeat daily

# Add with notes
rems add MyList "Call dentist" --notes "Ask about insurance"

# Complete reminders (supports batch)
rems complete MyList 0 1 2

# Complete with dry-run
rems complete MyList 0 1 --dry-run

# Uncomplete a reminder
rems uncomplete MyList 0

# Edit a reminder
rems edit MyList 0 --due-date "next monday" --priority medium

# Clear due date from a reminder
rems edit MyList 0 --clear-due-date

# Delete a reminder (prompts for confirmation)
rems delete MyList 0

# Delete without confirmation
rems delete MyList 0 --force

# Move a reminder between lists
rems move SourceList 0 TargetList

# Create a list on move if it doesn't exist
rems move SourceList 0 NewList --create

# List management
rems lists new MyNewList
rems lists rename OldName NewName
rems lists delete EmptyList --force

# Clean up all empty lists
rems lists clean
rems lists clean --dry-run

# Check authorization status
rems auth status

# Request Reminders access
rems auth request

# JSON output
rems show MyList --format json

# Table output
rems show MyList --format table

# TSV output for scripting
rems show --format tsv

# Quiet mode (counts only)
rems show --format quiet
```

## Credits

This project merges features from two macOS Reminders CLI tools:

- [keith/reminders-cli](https://github.com/keith/reminders-cli) — the original tool providing core Reminders integration, natural language dates, and the foundation this project builds on
- [steipete/remindctl](https://github.com/steipete/remindctl) — batch operations, dry-run mode, multiple output formats, list rename, and permission management

## License

MIT
