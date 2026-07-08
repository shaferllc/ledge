import Foundation
import Observation

/// A tiny Claude assistant in the notch (⌘⌥Space). Prefers the local Claude Code
/// CLI (`claude -p`), so no API key is needed — it uses your existing CLI login.
/// Falls back to the Anthropic Messages API over HTTPS+SSE if a key is set and
/// the CLI isn't available.
@Observable
@MainActor
final class ClaudeModel {
    var prompt = ""
    private(set) var answer = ""
    private(set) var streaming = false
    private(set) var errorText: String?
    private var task: Task<Void, Never>?

    var hasKey: Bool { AnthropicKey.hasKey }

    func ask() {
        let question = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !streaming else { return }
        answer = ""
        errorText = nil
        streaming = true
        task?.cancel()
        task = Task { await run(question: question) }
    }

    func reset() {
        task?.cancel()
        streaming = false
        prompt = ""
        answer = ""
        errorText = nil
    }

    private func run(question: String) async {
        // 1. Try the terminal `claude` CLI first (no API key required).
        let result = await Self.streamCLI(prompt: question) { [weak self] delta in
            Task { @MainActor in self?.answer += delta }
        }
        if result.produced {
            streaming = false
            return
        }
        // 2. Fall back to the API if a key is configured.
        if let key = AnthropicKey.load() {
            await streamAPI(question: question, key: key)
            return
        }
        streaming = false
        errorText = result.error
            ?? "Couldn't run the `claude` CLI. Install Claude Code, or set an API key from the menu bar."
    }

    // MARK: Terminal CLI (`claude -p`)

    /// Runs `claude -p` through a login shell (the GUI app doesn't inherit your
    /// shell PATH), streaming stdout via `onDelta`. The prompt is passed as an
    /// environment variable so there's no shell-escaping or injection.
    private static func streamCLI(
        prompt: String, onDelta: @escaping @Sendable (String) -> Void
    ) async -> (produced: Bool, error: String?) {
        await withCheckedContinuation { continuation in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
            proc.arguments = ["-lc",
                #"export PATH="$HOME/.local/bin:$HOME/.claude/local:/opt/homebrew/bin:/usr/local/bin:$PATH"; exec claude -p "$LEDGE_PROMPT""#]
            var env = ProcessInfo.processInfo.environment
            env["LEDGE_PROMPT"] = prompt
            proc.environment = env

            let out = Pipe(), err = Pipe()
            proc.standardOutput = out
            proc.standardError = err
            proc.standardInput = FileHandle.nullDevice

            // Collects state across the readability/termination callbacks, which
            // run on background threads.
            final class Box: @unchecked Sendable {
                var produced = false
                var stderr = ""
            }
            let box = Box()

            out.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                box.produced = true
                if let text = String(data: data, encoding: .utf8) { onDelta(text) }
            }
            err.fileHandleForReading.readabilityHandler = { handle in
                if let text = String(data: handle.availableData, encoding: .utf8), !text.isEmpty {
                    box.stderr += text
                }
            }
            proc.terminationHandler = { p in
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                let error: String?
                if box.produced {
                    error = nil
                } else if box.stderr.contains("command not found") {
                    error = nil   // CLI absent — let the caller fall back silently
                } else {
                    let trimmed = box.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                    error = trimmed.isEmpty ? "claude exited (code \(p.terminationStatus))." : trimmed
                }
                continuation.resume(returning: (box.produced, error))
            }

            do {
                try proc.run()
            } catch {
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                continuation.resume(returning: (false, nil))
            }
        }
    }

    // MARK: Anthropic API fallback (HTTPS + SSE)

    private func streamAPI(question: String, key: String) async {
        defer { streaming = false }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 1024,
            "stream": true,
            "system": "You are a concise assistant living in the macOS notch. "
                + "Answer directly in a sentence or two; no preamble.",
            "messages": [["role": "user", "content": question]],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                errorText = "No response from the server."
                return
            }
            guard http.statusCode == 200 else {
                errorText = await Self.readError(from: bytes, status: http.statusCode)
                return
            }
            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard let data = payload.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { continue }
                switch obj["type"] as? String {
                case "content_block_delta":
                    if let delta = obj["delta"] as? [String: Any],
                       delta["type"] as? String == "text_delta",
                       let text = delta["text"] as? String {
                        answer += text
                    }
                case "error":
                    if let err = obj["error"] as? [String: Any] {
                        errorText = err["message"] as? String ?? "Streaming error."
                    }
                default:
                    break
                }
            }
        } catch {
            if !Task.isCancelled { errorText = error.localizedDescription }
        }
    }

    private static func readError(from bytes: URLSession.AsyncBytes, status: Int) async -> String {
        var raw = ""
        do { for try await line in bytes.lines { raw += line } } catch {}
        if let data = raw.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? [String: Any],
           let message = err["message"] as? String {
            return message
        }
        return "Request failed (HTTP \(status))."
    }
}
