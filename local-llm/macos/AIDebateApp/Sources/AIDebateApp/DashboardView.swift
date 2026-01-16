import SwiftUI

struct DashboardView: View {
    @ObservedObject var debateManager: DebateManager

    @AppStorage("ollamaServerURL") private var serverURLString = "http://localhost:11434"
    @AppStorage("ollamaModel") private var modelOverride = ""
    @AppStorage("debateTemperature") private var temperature = 0.7
    @AppStorage("debateMaxTokens") private var maxTokens = 256
    @AppStorage("debateAutoContext") private var autoContext = true

    @State private var topic: String = ""
    @State private var showSettings = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                content
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                serverURLString: $serverURLString,
                model: $modelOverride,
                temperature: $temperature,
                maxTokens: $maxTokens
            )
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .onAppear {
            debateManager.refreshHealth(serverURLString: serverURLString)
        }
        .onChange(of: serverURLString) { _ in
            debateManager.refreshHealth(serverURLString: serverURLString)
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.95, blue: 1.0),
                    Color.white,
                    Color(red: 0.96, green: 0.95, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 0.93, green: 0.95, blue: 1.0), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 520
            )
            RadialGradient(
                colors: [Color(red: 0.96, green: 0.95, blue: 1.0), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                PillButton(
                    title: "Auto context",
                    isOn: autoContext,
                    dotColor: autoContext ? Color.purple : Color.gray
                ) {
                    autoContext.toggle()
                }

                HealthPill(status: debateManager.healthStatus)
            }

            Spacer(minLength: 12)

            BrandMark()

            Spacer(minLength: 12)

            Button("Settings") { showSettings = true }
                .buttonStyle(.bordered)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.thinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var content: some View {
        VStack(spacing: 18) {
            hero
            agentMatchup
            conversationPanel
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Text("Two AI engineers. Same template. Different perspective.")
                .font(.system(size: 14, weight: .thin))
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                Text("Local")
                    .font(.system(size: 36, weight: .ultraLight))
                Text("AI Debate")
                    .font(.system(size: 36, weight: .thin))
            }
            .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))

            Text("Type a technical topic. AgentX and AgentC respond in the same structured format, using SF UltraThin/Thin/Light typography.")
                .font(.system(size: 13, weight: .thin))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)

            chips
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var chips: some View {
        let items: [(String, String)] = [
            ("Microservices vs Monolith", "Microservices vs Monolithic Architecture"),
            ("REST vs GraphQL", "REST vs GraphQL API Design"),
            ("SQL vs NoSQL", "SQL vs NoSQL Databases"),
            ("TDD vs BDD", "TDD vs BDD Testing Approaches")
        ]

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 8, alignment: .center)],
            spacing: 8
        ) {
            ForEach(items, id: \.0) { title, value in
                Button(title) {
                    topic = value
                    startDebate()
                }
                .buttonStyle(ChipButtonStyle())
                .disabled(debateManager.isRunning)
            }
        }
        .frame(maxWidth: 760)
    }

    private var agentMatchup: some View {
        HStack(spacing: 18) {
            AgentProfile(
                name: "AgentX",
                role: "Creative Engineer",
                trait: "Innovative",
                accent: .purple,
                imageURL: URL(string: "https://ucarecdn.com/82e21364-f8e6-4526-9464-16cac4cfaba6/-/format/auto/")!
            )

            MatchVS()

            AgentProfile(
                name: "AgentC",
                role: "Logical Engineer",
                trait: "Systematic",
                accent: .blue,
                imageURL: URL(string: "https://ucarecdn.com/1d3af6f0-a64f-4a71-a100-414802839a19/-/format/auto/")!
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var conversationPanel: some View {
        ConversationPanel(
            rounds: debateManager.rounds,
            modelLabel: debateManager.modelLabel,
            statusText: debateManager.subheadText(serverURLString: serverURLString, autoContext: autoContext),
            isRunning: debateManager.isRunning,
            onNextRound: { nextRound() },
            onReset: { debateManager.reset() }
        )
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                TextField("Enter a technical topic for both AI engineers to debate…", text: $topic, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                    .disabled(debateManager.isRunning)

                Button(debateManager.isRunning ? "Running…" : "Start Debate") {
                    startDebate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(debateManager.isRunning || topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            HStack {
                Text("Endpoint \(serverURLString) • Model \(debateManager.modelLabel)")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.secondary)

                Spacer()

                if let status = debateManager.statusMessage, !status.isEmpty {
                    Text(status)
                        .font(.system(size: 12, weight: .thin))
                        .foregroundColor(debateManager.lastError == nil ? .secondary : .red)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.thinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func startDebate() {
        debateManager.startDebate(
            topic: topic,
            serverURLString: serverURLString,
            modelOverride: modelOverride,
            temperature: temperature,
            maxTokens: maxTokens,
            autoContext: autoContext
        )
    }

    private func nextRound() {
        debateManager.nextRound(
            serverURLString: serverURLString,
            modelOverride: modelOverride,
            temperature: temperature,
            maxTokens: maxTokens,
            autoContext: autoContext
        )
    }
}

private struct BrandMark: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 2) {
                Text("Agent")
                    .font(.system(size: 20, weight: .ultraLight))
                Text("X")
                    .font(.system(size: 20, weight: .light))
            }
            MidVsBadge()
            HStack(spacing: 2) {
                Text("Agent")
                    .font(.system(size: 20, weight: .ultraLight))
                Text("C")
                    .font(.system(size: 20, weight: .light))
            }
        }
        .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))
    }
}

private struct MidVsBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.18), Color.blue.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))

            (Text("V").font(.system(size: 14, weight: .light)) + Text("s").font(.system(size: 14, weight: .thin)))
                .foregroundColor(Color.black.opacity(0.84))
        }
        .frame(width: 44, height: 44)
    }
}

private struct PillButton: View {
    let title: String
    let isOn: Bool
    let dotColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(dotColor.opacity(0.25), lineWidth: 6).blur(radius: 6))
                Text(title)
                    .font(.system(size: 13, weight: .thin))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isOn ? Color.purple.opacity(0.10) : Color.white.opacity(0.45))
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
        )
    }
}

private struct HealthPill: View {
    let status: OllamaHealthStatus

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.dotColor)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(status.dotColor.opacity(0.25), lineWidth: 6).blur(radius: 6))
            Text(status.label)
                .font(.system(size: 13, weight: .thin))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.45))
                .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
        )
    }
}

private extension OllamaHealthStatus {
    var label: String {
        switch self {
        case .ok:
            return "Local"
        case .issue:
            return "Issue"
        case .down:
            return "Down"
        case .unknown:
            return "Checking"
        }
    }

    var dotColor: Color {
        switch self {
        case .ok:
            return Color.green
        case .issue:
            return Color.orange
        case .down:
            return Color.red
        case .unknown:
            return Color.gray
        }
    }
}

private struct MatchVS: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: Color.purple.opacity(0.25), radius: 18)
            Text("VS")
                .font(.system(size: 18, weight: .thin))
                .foregroundColor(.white)
                .tracking(1.5)
        }
        .frame(width: 70, height: 70)
    }
}

private struct AgentProfile: View {
    let name: String
    let role: String
    let trait: String
    let accent: Color
    let imageURL: URL

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 120, height: 120)
                case .failure:
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(accent.opacity(0.8))
                        .frame(width: 120, height: 120)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: 10)
                @unknown default:
                    EmptyView()
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.system(size: 24, weight: .thin))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))

                Text(role)
                    .font(.system(size: 12, weight: .thin))
                    .foregroundColor(.secondary)

                Text(trait)
                    .font(.system(size: 12, weight: .thin))
                    .foregroundColor(accent.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .thin))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.85 : 0.58))
                    .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
    }
}
