import Foundation

/// Runs AppleScript out-of-process via `osascript`. Using a subprocess (rather
/// than NSAppleScript) keeps execution off the main thread and side-steps
/// NSAppleScript's thread-safety constraints.
enum AppleScriptRunner {
    /// Runs `source` and returns trimmed stdout, or nil on any failure.
    /// Blocking — call from a background queue.
    static func run(_ source: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-"] // read script from stdin

        let stdin = Pipe()
        let stdout = Pipe()
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = Pipe()

        do {
            try proc.run()
        } catch {
            return nil
        }

        stdin.fileHandleForWriting.write(Data(source.utf8))
        stdin.fileHandleForWriting.closeFile()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }

        let out = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? nil : out
    }
}
