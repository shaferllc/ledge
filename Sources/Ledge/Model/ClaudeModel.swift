import Foundation
import Observation

/// A tiny Claude assistant in the notch. Streams a single-turn answer from the
/// Anthropic Messages API (raw HTTPS + SSE — there's no official Swift SDK).
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
        guard let key = AnthropicKey.load() else {
            errorText = "Set your Anthropic API key from the menu bar first."
            return
        }
        answer = ""
        errorText = nil
        streaming = true
        task?.cancel()
        task = Task { await stream(question: question, key: key) }
    }

    func reset() {
        task?.cancel()
        streaming = false
        prompt = ""
        answer = ""
        errorText = nil
    }

    private func stream(question: String, key: String) async {
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
            // Parse the SSE stream: lines like `data: {json}`; text arrives in
            // content_block_delta events with a text_delta.
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

    /// Reads a non-200 response body and extracts the API error message.
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
