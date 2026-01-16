import SwiftUI

struct SettingsView: View {
    @Binding var serverURLString: String
    @Binding var model: String
    @Binding var temperature: Double
    @Binding var maxTokens: Int

    @Environment(\.dismiss) private var dismiss

    @State private var isTestingConnection = false
    @State private var connectionResult: String?
    @State private var availableModels: [String] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Ollama") {
                    TextField("Server URL", text: $serverURLString)

                    TextField("Model", text: $model)

                    Button(isTestingConnection ? "Testing…" : "Test Connection") {
                        testConnection()
                    }
                    .disabled(isTestingConnection)

                    if let connectionResult {
                        Text(connectionResult)
                            .foregroundColor(connectionResult.hasPrefix("Connected") ? .green : .red)
                    }

                    if !availableModels.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Available Models")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ForEach(availableModels.prefix(8), id: \.self) { name in
                                Text(name)
                                    .font(.callout)
                            }
                            if availableModels.count > 8 {
                                Text("…and \(availableModels.count - 8) more")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Debate") {
                    LabeledContent("Temperature") {
                        Text(String(format: "%.2f", temperature))
                            .monospacedDigit()
                    }
                    Slider(value: $temperature, in: 0.1...2.0, step: 0.05)

                    Stepper("Max Tokens: \(maxTokens)", value: $maxTokens, in: 64...2048, step: 64)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 520)
    }

    private func testConnection() {
        let currentServerURL = serverURLString
        isTestingConnection = true
        connectionResult = nil
        availableModels = []

        Task {
            do {
                let baseURL = try OllamaClient.parseBaseURL(from: currentServerURL)
                let models = try await OllamaClient(baseURL: baseURL).listModels()
                await MainActor.run {
                    availableModels = models
                    connectionResult = "Connected (\(models.count) model\(models.count == 1 ? "" : "s"))"
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionResult = error.localizedDescription
                    isTestingConnection = false
                }
            }
        }
    }
}
