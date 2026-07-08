import AppKit

/// Prompts the user to paste their Anthropic API key into a secure field and
/// stores it in the keychain. The key is entered by the user directly; Ledge
/// only saves it and never displays it back.
@MainActor
enum AnthropicKeyPrompt {
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Claude API Key"
        alert.informativeText = "Paste your Anthropic API key (sk-ant-…). "
            + "It's stored in your login keychain and used only to answer notch questions (⌘⌥Space).\n\n"
            + "Get a key at console.anthropic.com."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        if AnthropicKey.hasKey { alert.addButton(withTitle: "Remove Key") }

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "sk-ant-…"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        switch alert.runModal() {
        case .alertFirstButtonReturn:      // Save
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return }
            AnthropicKey.save(value)
        case .alertThirdButtonReturn:      // Remove Key (only present when a key exists)
            AnthropicKey.clear()
        default:
            break
        }
    }
}
