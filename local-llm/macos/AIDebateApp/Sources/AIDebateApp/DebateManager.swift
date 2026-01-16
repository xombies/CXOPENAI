import Foundation

@MainActor
final class DebateManager: ObservableObject {
    @Published var rounds: [DebateRound] = []
    @Published var isRunning = false
    @Published var lastError: String?
    @Published var statusMessage: String?
    @Published var healthStatus: OllamaHealthStatus = .unknown

    private var currentTask: Task<Void, Never>?
    private var healthTask: Task<Void, Never>?
    private var resolvedModel: String?

    var modelLabel: String {
        resolvedModel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (resolvedModel ?? "auto") : "auto"
    }

    func refreshHealth(serverURLString: String) {
        healthTask?.cancel()
        healthTask = Task { @MainActor in
            do {
                let baseURL = try OllamaClient.parseBaseURL(from: serverURLString)
                _ = try await OllamaClient(baseURL: baseURL).version()
                healthStatus = .ok
            } catch is CancellationError {
                // ignore
            } catch {
                healthStatus = .down
            }
        }
    }

    func subheadText(serverURLString: String, autoContext: Bool) -> String {
        let contextLabel = autoContext ? "Auto context" : "Manual context"
        switch healthStatus {
        case .ok:
            return "Ollama OK • \(contextLabel) • \(serverURLString)"
        case .issue:
            return "Ollama issue • \(contextLabel) • \(serverURLString)"
        case .down:
            return "Ollama down • \(contextLabel) • \(serverURLString)"
        case .unknown:
            return "Checking Ollama… • \(contextLabel) • \(serverURLString)"
        }
    }

    func startDebate(
        topic: String,
        serverURLString: String,
        modelOverride: String,
        temperature: Double,
        maxTokens: Int,
        autoContext: Bool
    ) {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty else {
            lastError = "Enter a topic to debate."
            statusMessage = lastError
            return
        }

        stop()
        lastError = nil
        statusMessage = "Running…"
        isRunning = true

        let safeMaxTokens = max(32, min(maxTokens, 2048))
        let agentXTemp = max(0.1, min(2.0, temperature))
        let agentCTemp = max(0.1, min(2.0, temperature * 0.3))

        currentTask = Task { @MainActor [trimmedTopic] in
            defer {
                isRunning = false
                currentTask = nil
            }

            do {
                let baseURL = try OllamaClient.parseBaseURL(from: serverURLString)
                let client = OllamaClient(baseURL: baseURL)
                let model = try await resolveModel(client: client, modelOverride: modelOverride)

                let x = try await client.generate(
                    model: model,
                    system: agentXSystemPrompt,
                    prompt: startPrompt(topic: trimmedTopic, for: .agentX),
                    temperature: agentXTemp,
                    maxTokens: safeMaxTokens,
                    contextWindow: 2048
                )

                let c = try await client.generate(
                    model: model,
                    system: agentCSystemPrompt,
                    prompt: startPrompt(topic: trimmedTopic, for: .agentC),
                    temperature: agentCTemp,
                    maxTokens: safeMaxTokens,
                    contextWindow: 2048
                )

                let round = DebateRound(
                    topic: trimmedTopic,
                    model: model,
                    agentX: normalizeBullets(x),
                    agentC: normalizeBullets(c)
                )

                rounds = [round]
                resolvedModel = model
                statusMessage = ""
                refreshHealth(serverURLString: serverURLString)
            } catch is CancellationError {
                // user stopped
            } catch {
                lastError = error.localizedDescription
                statusMessage = lastError
                refreshHealth(serverURLString: serverURLString)
            }
        }
    }

    func nextRound(
        serverURLString: String,
        modelOverride: String,
        temperature: Double,
        maxTokens: Int,
        autoContext: Bool
    ) {
        guard !rounds.isEmpty else {
            lastError = "Start a debate first."
            statusMessage = lastError
            return
        }

        stop()
        lastError = nil
        statusMessage = "Continuing…"
        isRunning = true

        let safeMaxTokens = max(32, min(maxTokens, 2048))
        let agentXTemp = max(0.1, min(2.0, temperature))
        let agentCTemp = max(0.1, min(2.0, temperature * 0.3))

        currentTask = Task { @MainActor in
            defer {
                isRunning = false
                currentTask = nil
            }

            do {
                let baseURL = try OllamaClient.parseBaseURL(from: serverURLString)
                let client = OllamaClient(baseURL: baseURL)
                let model = try await resolveModel(client: client, modelOverride: modelOverride)

                let promptX = continuePrompt(for: .agentX, autoContext: autoContext)
                let promptC = continuePrompt(for: .agentC, autoContext: autoContext)

                let x = try await client.generate(
                    model: model,
                    system: agentXSystemPrompt,
                    prompt: promptX,
                    temperature: agentXTemp,
                    maxTokens: safeMaxTokens,
                    contextWindow: 2048
                )

                let c = try await client.generate(
                    model: model,
                    system: agentCSystemPrompt,
                    prompt: promptC,
                    temperature: agentCTemp,
                    maxTokens: safeMaxTokens,
                    contextWindow: 2048
                )

                let next = DebateRound(
                    topic: rounds.last?.topic ?? "Debate",
                    model: model,
                    agentX: normalizeBullets(x),
                    agentC: normalizeBullets(c)
                )
                rounds.append(next)
                resolvedModel = model
                statusMessage = ""
                refreshHealth(serverURLString: serverURLString)
            } catch is CancellationError {
                // user stopped
            } catch {
                lastError = error.localizedDescription
                statusMessage = lastError
                refreshHealth(serverURLString: serverURLString)
            }
        }
    }

    func stop() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
    }

    func reset() {
        stop()
        rounds = []
        lastError = nil
        statusMessage = ""
    }
}

private let outputContract = """
Output ONLY plain-text bullets.
Write 3–5 bullets starting with "- Outcome: ".
End with exactly one bullet starting with "- Question: " and include a "?".
No markdown and never use **.
If you include terminal commands, wrap them in single backticks.
The Question MUST ask which client preference/constraint matters most and whether to favor AgentX, AgentC, or a hybrid.
"""

private let agentXSystemPrompt = """
You are AgentX, a creative, exploratory senior engineer.
\(outputContract)
"""

private let agentCSystemPrompt = """
You are AgentC, a structured, skeptical senior engineer.
\(outputContract)
"""

private func startPrompt(topic: String, for speaker: DebateSpeaker) -> String {
    switch speaker {
    case .agentX:
        return """
Debate topic: \(topic)

Be bold, creative, and practical.
"""
    case .agentC:
        return """
Debate topic: \(topic)

Be skeptical, systematic, and reliability-focused.
"""
    case .system:
        return "System."
    }
}

private extension DebateManager {
    func continuePrompt(for speaker: DebateSpeaker, autoContext: Bool) -> String {
        let topic = rounds.last?.topic ?? "Debate"

        var parts: [String] = ["Topic: \(topic)"]

        if autoContext {
            let transcript = rounds
                .enumerated()
                .map { idx, r in
                    let n = idx + 1
                    return """
Round \(n)
Agent X:
\(clip(r.agentX, maxChars: 900))

Agent C:
\(clip(r.agentC, maxChars: 900))
"""
                }
                .joined(separator: "\n\n")

            parts.append(contentsOf: ["Conversation so far:", transcript])
        } else if let last = rounds.last {
            parts.append(contentsOf: [
                "Previous round:",
                "Agent X:\n\(clip(last.agentX, maxChars: 1200))",
                "Agent C:\n\(clip(last.agentC, maxChars: 1200))"
            ])
        }

        parts.append("Continue the debate for one more round.")

        switch speaker {
        case .agentX:
            parts.append("Be bold, creative, and practical.")
        case .agentC:
            parts.append("Be skeptical, systematic, and reliability-focused.")
        case .system:
            break
        }

        return parts.joined(separator: "\n\n")
    }

    func resolveModel(client: OllamaClient, modelOverride: String) async throws -> String {
        let overrideTrimmed = modelOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if !overrideTrimmed.isEmpty {
            return overrideTrimmed
        }

        let models = try await client.listModels()
        let lower = Set(models.map { $0.lowercased() })

        let preferred: [String] = [
            "mk-x-gemma:1b",
            "gemma3:1b",
            "gemma3:4b",
            "gemma3:12b",
            "gemma3:27b"
        ]

        if let match = preferred.first(where: { lower.contains($0.lowercased()) }) {
            return match
        }

        if let gemma = models.first(where: { $0.lowercased().contains("gemma") }) {
            return gemma
        }

        return models.first ?? "auto"
    }
}

private func normalizeBullets(_ text: String) -> String {
    let raw = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "**", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    guard !raw.isEmpty else { return "" }

    let lines = raw
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map { stripBulletPrefix(String($0)) }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    guard !lines.isEmpty else { return raw }

    let isQuestion: (String) -> Bool = { line in
        let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("question:") { return true }
        return t.hasSuffix("?")
    }

    let lastQuestionIdx = lines.indices.reversed().first(where: { isQuestion(lines[$0]) })

    let outcomesRaw: [String]
    let questionRaw: String

    if let idx = lastQuestionIdx {
        questionRaw = String(lines[idx])
        outcomesRaw = lines.enumerated().compactMap { $0.offset == idx ? nil : String($0.element) }
    } else {
        outcomesRaw = Array(lines)
        questionRaw = ""
    }

    let maxOutcomes = 5
    let maxWords = 16

    var bullets: [String] = []
    for o in outcomesRaw.prefix(maxOutcomes) {
        let cleaned = o.replacingOccurrences(of: "Outcome:", with: "", options: [.caseInsensitive, .anchored]).trimmingCharacters(in: .whitespacesAndNewlines)
        let labeled = "Outcome: \(cleaned)"
        bullets.append("- \(clipWordsPreservingBackticks(labeled, maxWords: maxWords))")
    }

    let question = ensureQuestion(questionRaw)
    bullets.append("- \(clipWordsPreservingBackticks(question, maxWords: maxWords))")

    return bullets.joined(separator: "\n")
}

private func ensureQuestion(_ text: String) -> String {
    let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let base = t.replacingOccurrences(of: "Question:", with: "", options: [.caseInsensitive, .anchored]).trimmingCharacters(in: .whitespacesAndNewlines)
    let questionBody = base.isEmpty
        ? "Favor AgentX, AgentC, or hybrid—what client outcome matters most"
        : base
    let prefixed = "Question: \(questionBody)"
    return prefixed.hasSuffix("?") ? prefixed : prefixed + "?"
}

private func clipWordsPreservingBackticks(_ text: String, maxWords: Int) -> String {
    let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return "" }

    var tokens: [String] = []
    var i = s.startIndex

    while i < s.endIndex {
        while i < s.endIndex, s[i].isWhitespace {
            i = s.index(after: i)
        }
        if i >= s.endIndex { break }

        if s[i] == "`" {
            let next = s.index(after: i)
            if let end = s[next...].firstIndex(of: "`") {
                tokens.append(String(s[i...end]))
                i = s.index(after: end)
                continue
            }
            tokens.append(String(s[i...]))
            break
        }

        var j = i
        while j < s.endIndex, !s[j].isWhitespace {
            j = s.index(after: j)
        }
        tokens.append(String(s[i..<j]))
        i = j
    }

    if tokens.count <= maxWords { return tokens.joined(separator: " ") }
    return tokens.prefix(maxWords).joined(separator: " ") + "…"
}

private func clip(_ text: String, maxChars: Int) -> String {
    let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.count <= maxChars { return s }
    return String(s.prefix(maxChars)) + "…"
}

private func stripBulletPrefix(_ line: String) -> String {
    var s = line.trimmingCharacters(in: .whitespacesAndNewlines)

    if let first = s.first, first == "-" || first == "*" || first == "•" {
        s.removeFirst()
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var digitsPrefix = ""
    for ch in s.prefix(6) {
        if ch.isNumber {
            digitsPrefix.append(ch)
        } else {
            break
        }
    }
    if !digitsPrefix.isEmpty {
        let idx = s.index(s.startIndex, offsetBy: digitsPrefix.count)
        if idx < s.endIndex {
            let after = s[idx...]
            if after.hasPrefix(".") || after.hasPrefix(")") {
                s = String(after.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    return s
}
