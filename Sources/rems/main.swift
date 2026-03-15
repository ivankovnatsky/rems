import Darwin
import RemsLibrary

do {
    var command = try CLI.parseAsRoot()

    if !CLI.commandSkipsAccess(command) {
        switch Reminders.requestAccess() {
        case (true, _):
            break
        case (false, let error):
            print("error: you need to grant reminders access")
            if let error {
                print("error: \(error.localizedDescription)")
            }
            Darwin.exit(1)
        }
    }

    try command.run()
} catch {
    CLI.exit(withError: error)
}
