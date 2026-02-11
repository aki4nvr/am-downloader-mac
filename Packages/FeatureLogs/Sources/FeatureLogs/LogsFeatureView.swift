import SwiftUI
import AppKit

public struct LogsFeatureView: View {
    @ObservedObject private var backend: BackendBridgeService
    private let language: AppLanguage

    @State private var autoScroll = true

    public init(backend: BackendBridgeService, language: AppLanguage) {
        self.backend = backend
        self.language = language
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle(L10n.tr("logs.autoscroll", locale: language), isOn: $autoScroll)
                Button(L10n.tr("logs.clear", locale: language)) { backend.resetLogs() }
                Button(L10n.tr("logs.export", locale: language)) { exportLogs() }
            }

            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(backend.logs) { line in
                            Text(line.raw)
                                .foregroundStyle(color(for: line.severity))
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .textSelection(.enabled)
                .onChange(of: backend.logs.count) {
                    guard autoScroll, let last = backend.logs.last else { return }
                    reader.scrollTo(last.id, anchor: .bottom)
                }
            }

            if !backend.detectedFiles.isEmpty {
                Text("Detected Files")
                    .font(.headline)
                ForEach(backend.detectedFiles, id: \.self) { file in
                    Text(file).font(.caption)
                }
            }
        }
        .padding(16)
    }

    private func color(for severity: LogSeverity) -> Color {
        switch severity {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        }
    }

    private func exportLogs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "amdl-logs.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let text = backend.logs.map(\.raw).joined(separator: "\n")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
