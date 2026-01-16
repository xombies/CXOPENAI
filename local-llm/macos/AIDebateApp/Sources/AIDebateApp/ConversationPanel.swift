import SwiftUI

struct ConversationPanel: View {
    let rounds: [DebateRound]
    let modelLabel: String
    let statusText: String
    let isRunning: Bool
    let onNextRound: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.6)

            bodyView
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Conversation")
                    .font(.system(size: 14, weight: .thin))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))

                Text(statusText)
                    .font(.system(size: 12, weight: .thin))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Next Round", action: onNextRound)
                    .buttonStyle(.bordered)
                    .disabled(isRunning || rounds.isEmpty)

                Button("Reset", role: .destructive, action: onReset)
                    .buttonStyle(.bordered)
                    .disabled(isRunning || rounds.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.10))
    }

    private var bodyView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if rounds.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(rounds.enumerated()), id: \.element.id) { idx, round in
                            RoundCard(round: round, roundNumber: idx + 1)
                                .id(round.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onAppear {
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: rounds.count) { _ in
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
        .frame(maxHeight: 520)
    }

    private var emptyState: some View {
        HStack {
            Text("Enter a topic below to start the debate.")
                .font(.system(size: 13, weight: .thin))
                .foregroundColor(.secondary)
                .padding(16)

            Spacer()
        }
        .background(Color.white.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundColor(Color.black.opacity(0.20))
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        guard !rounds.isEmpty else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("BOTTOM", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("BOTTOM", anchor: .bottom)
        }
    }
}

private struct RoundCard: View {
    let round: DebateRound
    let roundNumber: Int

    var body: some View {
        VStack(spacing: 0) {
            meta

            Divider()
                .opacity(0.6)

            answers
                .padding(12)
        }
        .background(Color.white.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var meta: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Round \(roundNumber)")
                    .font(.system(size: 12, weight: .thin))
                    .foregroundColor(.secondary)

                Text(round.topic)
                    .font(.system(size: 14, weight: .thin))
                    .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Model: \(round.model)")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(round.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var answers: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                AnswerCard(
                    agentLetter: "X",
                    role: "Creative Engineer",
                    accent: .purple,
                    content: round.agentX
                )

                SmallVS()
                    .padding(.top, 6)

                AnswerCard(
                    agentLetter: "C",
                    role: "Logical Engineer",
                    accent: .blue,
                    content: round.agentC
                )
            }

            VStack(spacing: 12) {
                AnswerCard(
                    agentLetter: "X",
                    role: "Creative Engineer",
                    accent: .purple,
                    content: round.agentX
                )
                SmallVS()
                AnswerCard(
                    agentLetter: "C",
                    role: "Logical Engineer",
                    accent: .blue,
                    content: round.agentC
                )
            }
        }
    }
}

private struct SmallVS: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.purple, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: Color.purple.opacity(0.18), radius: 16)
            Text("VS")
                .font(.system(size: 13, weight: .thin))
                .foregroundColor(.white)
                .tracking(1.6)
        }
        .frame(width: 52, height: 52)
    }
}

private struct AnswerCard: View {
    let agentLetter: String
    let role: String
    let accent: Color
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 2) {
                    Text("Agent")
                        .font(.system(size: 14, weight: .ultraLight))
                    Text(agentLetter)
                        .font(.system(size: 14, weight: .light))
                }
                .foregroundColor(Color(red: 0.06, green: 0.09, blue: 0.19))

                Spacer()

                Text(role)
                    .font(.system(size: 11, weight: .thin))
                    .foregroundColor(.secondary)
            }

            TerminalHighlightedText(text: content)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.26), lineWidth: 1)
        )
    }

    private var background: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.10), Color.white.opacity(0.22)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
