import Foundation

enum DebateSpeaker: String, Codable, Sendable {
    case system = "System"
    case agentX = "AgentX"
    case agentC = "AgentC"
}

struct DebateMessage: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let speaker: DebateSpeaker
    let content: String

    init(id: UUID = UUID(), speaker: DebateSpeaker, content: String) {
        self.id = id
        self.speaker = speaker
        self.content = content
    }
}

struct DebateRound: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let topic: String
    let model: String
    let agentX: String
    let agentC: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        topic: String,
        model: String,
        agentX: String,
        agentC: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.topic = topic
        self.model = model
        self.agentX = agentX
        self.agentC = agentC
        self.createdAt = createdAt
    }
}

enum OllamaHealthStatus: String, Sendable, Equatable {
    case unknown
    case ok
    case issue
    case down
}
