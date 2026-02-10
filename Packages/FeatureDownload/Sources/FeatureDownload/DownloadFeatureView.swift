import SwiftUI
import AppKit

@MainActor
public final class DownloadFeatureViewModel: ObservableObject {
    @Published public var urlsText: String = ""
    @Published public var statusMessage: String = ""
    @Published public var isError: Bool = false

    public init() {}

    public func start(
        settings: AppSettingsStore,
        backend: BackendBridgeService,
        launchContext: BackendLaunchContext
    ) {
        let urls = urlsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !urls.isEmpty else {
            statusMessage = L10n.tr("validation.urls", locale: settings.language)
            isError = true
            return
        }

        let cookies = settings.cookiePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cookies.isEmpty else {
            statusMessage = L10n.tr("validation.cookie", locale: settings.language)
            isError = true
            return
        }

        guard FileManager.default.fileExists(atPath: cookies) else {
            statusMessage = L10n.tr("validation.cookie_missing", locale: settings.language)
            isError = true
            return
        }

        let output = settings.outputPath.isEmpty ? "." : settings.outputPath
        if !ensureDirectoryExists(output) {
            statusMessage = L10n.tr("validation.output", locale: settings.language)
            isError = true
            return
        }

        let needsFfmpeg = settings.config.remuxMode == .ffmpeg || settings.config.downloadMode == .nm3u8dlre
        if needsFfmpeg && settings.config.toolPaths.ffmpeg.isEmpty {
            statusMessage = L10n.tr("validation.ffmpeg", locale: settings.language)
            isError = true
            return
        }

        if settings.config.remuxMode == .mp4box && settings.config.toolPaths.mp4box.isEmpty {
            statusMessage = L10n.tr("validation.mp4box", locale: settings.language)
            isError = true
            return
        }

        let needsMp4decrypt = settings.config.remuxMode == .mp4box || !settings.config.codecSong.isLegacy
        if needsMp4decrypt && settings.config.toolPaths.mp4decrypt.isEmpty {
            statusMessage = L10n.tr("validation.mp4decrypt", locale: settings.language)
            isError = true
            return
        }

        do {
            try backend.start(
                urls: urls,
                cookiesPath: cookies,
                outputPath: output,
                config: settings.config,
                launch: launchContext
            )
            statusMessage = ""
            isError = false
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    public func cancel(backend: BackendBridgeService) {
        backend.cancel()
    }

    private func ensureDirectoryExists(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            return isDir.boolValue
        }
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}

public struct DownloadFeatureView: View {
    @ObservedObject private var settings: AppSettingsStore
    @ObservedObject private var backend: BackendBridgeService
    @ObservedObject private var viewModel: DownloadFeatureViewModel
    private let launchContext: BackendLaunchContext

    public init(
        settings: AppSettingsStore,
        backend: BackendBridgeService,
        viewModel: DownloadFeatureViewModel,
        launchContext: BackendLaunchContext
    ) {
        self.settings = settings
        self.backend = backend
        self.viewModel = viewModel
        self.launchContext = launchContext
    }

    public var body: some View {
        HStack(spacing: 0) {
            downloadControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            LogsFeatureView(backend: backend, language: settings.language)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var downloadControls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox(L10n.tr("download.urls", locale: settings.language)) {
                    TextEditor(text: $viewModel.urlsText)
                        .frame(minHeight: 120)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.tr("download.cookie", locale: settings.language))
                            TextField("", text: $settings.cookiePath)
                            Button("…") { browseFile { settings.cookiePath = $0 } }
                        }
                        HStack {
                            Text(L10n.tr("download.output", locale: settings.language))
                            TextField("", text: $settings.outputPath)
                            Button("…") { browseDirectory { settings.outputPath = $0 } }
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("overwrite", isOn: $settings.config.overwrite)
                        Toggle("disable_music_video_skip", isOn: $settings.config.disableMusicVideoSkip)
                        Toggle("save_playlist", isOn: $settings.config.savePlaylist)
                        Toggle("synced_lyrics_only", isOn: $settings.config.syncedLyricsOnly)
                        Toggle("no_synced_lyrics", isOn: $settings.config.noSyncedLyrics)
                        Toggle("read_urls_as_txt", isOn: $settings.config.readUrlsAsTxt)
                        Toggle("no_exceptions", isOn: $settings.config.noExceptions)

                        Picker("Audio", selection: $settings.config.audioFormat) {
                            Text("保持原格式").tag(AudioConvertFormat.keep)
                            ForEach(AudioConvertFormat.allCases.filter { $0 != .keep }, id: \.self) { value in
                                Text(value.rawValue).tag(value)
                            }
                        }

                        Picker("Video", selection: $settings.config.videoFormat) {
                            Text("保持原格式").tag(VideoConvertFormat.keep)
                            ForEach(VideoConvertFormat.allCases.filter { $0 != .keep }, id: \.self) { value in
                                Text(value.rawValue).tag(value)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(L10n.tr("download.start", locale: settings.language)) {
                        viewModel.start(settings: settings, backend: backend, launchContext: launchContext)
                    }
                    .disabled(backend.isRunning)

                    Button(L10n.tr("download.cancel", locale: settings.language)) {
                        viewModel.cancel(backend: backend)
                    }
                    .disabled(!backend.isRunning)

                    ProgressView(value: progressValue)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 260)

                    Text("\(backend.completedURLCount)/\(max(backend.totalURLCount, 1))")
                        .font(.caption)
                }

                if !viewModel.statusMessage.isEmpty {
                    Text(viewModel.statusMessage)
                        .foregroundStyle(viewModel.isError ? Color.red : Color.green)
                }

                if let backendError = backend.lastError {
                    Text(backendError)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
        }
    }

    private var progressValue: Double {
        let total = max(backend.totalURLCount, 1)
        return Double(backend.completedURLCount) / Double(total)
    }

    private func browseFile(onSelect: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let path = panel.url?.path {
            onSelect(path)
        }
    }

    private func browseDirectory(onSelect: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let path = panel.url?.path {
            onSelect(path)
        }
    }
}
