import AppKit

/// Installs the bundled `ledge` command-line tool by symlinking it onto the
/// user's PATH, so scripts can push status into the notch (`ledge notify …`).
@MainActor
enum LedgeCLIInstaller {
    /// The `ledge` binary shipped in Contents/Resources (not MacOS — on the
    /// case-insensitive filesystem "ledge" there would collide with "Ledge").
    static var bundledCLI: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("ledge")
    }

    static var isBundled: Bool {
        guard let cli = bundledCLI else { return false }
        return FileManager.default.fileExists(atPath: cli.path)
    }

    static func install() {
        guard let src = bundledCLI, isBundled else {
            alert("The `ledge` CLI isn't included in this build.",
                  info: "Build the app with make-app.sh to bundle it.", style: .warning)
            return
        }
        let dest = URL(fileURLWithPath: "/usr/local/bin/ledge")
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? fm.removeItem(at: dest)
            try fm.createSymbolicLink(at: dest, withDestinationURL: src)
            alert("Installed the `ledge` command.",
                  info: "Try it in Terminal:\n\n    ledge notify \"hello from the notch\"",
                  style: .informational)
        } catch {
            // /usr/local/bin usually needs admin rights — hand the user a ready
            // command instead of failing silently.
            let cmd = "sudo ln -sf \"\(src.path)\" /usr/local/bin/ledge"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cmd, forType: .string)
            alert("Couldn't write to /usr/local/bin automatically.",
                  info: "A command was copied to your clipboard — paste it into Terminal:\n\n\(cmd)",
                  style: .warning)
        }
    }

    private static func alert(_ message: String, info: String, style: NSAlert.Style) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = message
        a.informativeText = info
        a.alertStyle = style
        a.runModal()
    }
}
