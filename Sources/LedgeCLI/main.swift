import Foundation

// `ledge` — a tiny CLI that pushes ambient status into the running Ledge app's
// notch. It posts a distributed notification and exits; the app (a separate
// process) observes it and renders a HUD. Fire-and-forget: if Ledge isn't
// running, the command is simply a no-op.

let commandName = "com.tomshafer.ledge.command"

let usage = """
ledge — push status into the Ledge notch

USAGE:
  ledge notify <message>            Flash a message in the notch
  ledge progress <0..1> [label]     Show/update a progress bar (sticky until 1.0)
  ledge timer <duration> [label]    Start a countdown (e.g. 25m, 90s, 1h)
  ledge clear                       Dismiss the current notch HUD
  ledge help                        Show this help

EXAMPLES:
  ledge notify "Deploy ✅"
  make 2>&1 | tail -1; ledge notify "Build done"
  ledge progress 0.42 "Uploading"
  ledge timer 25m Focus
"""

/// Parses "25m", "90s", "1h", "2h30m", or a bare seconds count into seconds.
func parseDuration(_ s: String) -> Int? {
    if let plain = Int(s) { return plain > 0 ? plain : nil }
    var total = 0
    var number = ""
    var sawUnit = false
    for ch in s.lowercased() {
        if ch.isNumber { number.append(ch); continue }
        guard let n = Int(number) else { return nil }
        switch ch {
        case "h": total += n * 3600
        case "m": total += n * 60
        case "s": total += n
        default: return nil
        }
        number = ""
        sawUnit = true
    }
    if !number.isEmpty { return nil }   // trailing number with no unit
    return sawUnit && total > 0 ? total : nil
}

func post(_ userInfo: [String: String]) {
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(commandName), object: nil, userInfo: userInfo,
        deliverImmediately: true)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { print(usage); exit(0) }
let rest = Array(args.dropFirst())

switch cmd {
case "notify", "hud":
    let message = rest.joined(separator: " ")
    guard !message.isEmpty else { fail("usage: ledge notify <message>") }
    post(["cmd": "notify", "text": message])

case "progress":
    guard let first = rest.first, let frac = Double(first) else {
        fail("usage: ledge progress <0..1> [label]")
    }
    let label = rest.dropFirst().joined(separator: " ")
    post(["cmd": "progress", "value": String(min(max(frac, 0), 1)), "text": label])

case "timer":
    guard let first = rest.first, let seconds = parseDuration(first) else {
        fail("usage: ledge timer <25m|90s|1h> [label]")
    }
    let label = rest.dropFirst().joined(separator: " ")
    post(["cmd": "timer", "value": String(seconds), "text": label])

case "clear", "hide":
    post(["cmd": "clear"])

case "help", "-h", "--help":
    print(usage)

default:
    fail("unknown command: \(cmd)\n\n\(usage)")
}
