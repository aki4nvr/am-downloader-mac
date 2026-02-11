import SwiftUI
import AppKit

public struct SettingsFeatureView: View {
    @ObservedObject private var settings: AppSettingsStore
    private let bundledToolsURL: URL?
    private let backendHealthCheck: () -> String

    public init(
        settings: AppSettingsStore,
        bundledToolsURL: URL?,
        backendHealthCheck: @escaping () -> String
    ) {
        self.settings = settings
        self.bundledToolsURL = bundledToolsURL
        self.backendHealthCheck = backendHealthCheck
    }

    @State private var healthMessage: String = ""
    @State private var installMessage: String = ""
    @State private var installMessageIsError = false

    public var body: some View {
        TabView {
            modeSection.tabItem { Text(L10n.tr("settings.mode", locale: settings.language)) }
            codecSection.tabItem { Text(L10n.tr("settings.codec", locale: settings.language)) }
            coverSection.tabItem { Text(L10n.tr("settings.cover", locale: settings.language)) }
            pathSection.tabItem { Text(L10n.tr("settings.paths", locale: settings.language)) }
            templateSection.tabItem { Text(L10n.tr("settings.templates", locale: settings.language)) }
            qualitySection.tabItem { Text(L10n.tr("settings.quality", locale: settings.language)) }
            appSection.tabItem { Text(L10n.tr("settings.app", locale: settings.language)) }
        }
        .padding(16)
    }

    private var modeSection: some View {
        Form {
            Picker("download_mode", selection: $settings.config.downloadMode) {
                ForEach(DownloadMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("remux_mode", selection: $settings.config.remuxMode) {
                ForEach(RemuxMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
    }

    private var codecSection: some View {
        Form {
            Picker("codec_song", selection: $settings.config.codecSong) {
                ForEach(SongCodec.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("codec_music_video", selection: $settings.config.codecMusicVideo) {
                ForEach(MusicVideoCodec.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
    }

    private var coverSection: some View {
        Form {
            Picker("cover_format", selection: $settings.config.coverFormat) {
                ForEach(CoverFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Stepper("cover_size: \(settings.config.coverSize)", value: $settings.config.coverSize, in: 90...10000)
            Stepper("truncate: \(settings.config.truncate ?? 0)", value: Binding(
                get: { settings.config.truncate ?? 0 },
                set: { settings.config.truncate = $0 == 0 ? nil : $0 }
            ), in: 0...1000)
            Picker("synced_lyrics_format", selection: $settings.config.syncedLyricsFormat) {
                ForEach(SyncedLyricsFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
    }

    private var pathSection: some View {
        Form {
            TextField("temp_path", text: $settings.config.tempPath)
            TextField("wvd_path", text: $settings.config.wvdPath)
            TextField("ffmpeg_path", text: $settings.config.toolPaths.ffmpeg)
            TextField("mp4decrypt_path", text: $settings.config.toolPaths.mp4decrypt)
            TextField("mp4box_path", text: $settings.config.toolPaths.mp4box)
            TextField("nm3u8dlre_path", text: $settings.config.toolPaths.nm3u8dlre)

            Button("Auto Detect") {
                settings.config.toolPaths.ffmpeg = ToolResolver.resolve(tool: .ffmpeg, overridePath: settings.config.toolPaths.ffmpeg, bundledRoot: bundledToolsURL) ?? ""
                settings.config.toolPaths.mp4decrypt = ToolResolver.resolve(tool: .mp4decrypt, overridePath: settings.config.toolPaths.mp4decrypt, bundledRoot: bundledToolsURL) ?? ""
                settings.config.toolPaths.mp4box = ToolResolver.resolve(tool: .mp4box, overridePath: settings.config.toolPaths.mp4box, bundledRoot: bundledToolsURL) ?? ""
                settings.config.toolPaths.nm3u8dlre = ToolResolver.resolve(tool: .nm3u8dlre, overridePath: settings.config.toolPaths.nm3u8dlre, bundledRoot: bundledToolsURL) ?? ""
            }
        }
    }

    private var templateSection: some View {
        Form {
            TextField("template_folder_album", text: $settings.config.templateFolderAlbum)
            TextField("template_folder_compilation", text: $settings.config.templateFolderCompilation)
            TextField("template_file_single_disc", text: $settings.config.templateFileSingleDisc)
            TextField("template_file_multi_disc", text: $settings.config.templateFileMultiDisc)
        }
    }

    private var qualitySection: some View {
        Form {
            Picker("quality_post", selection: $settings.config.qualityPost) {
                ForEach(PostQuality.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
    }

    private var appSection: some View {
        Form {
            Picker(L10n.tr("settings.language", locale: settings.language), selection: $settings.language) {
                Text("中文").tag(AppLanguage.chinese)
                Text("English").tag(AppLanguage.english)
            }

            Button(L10n.tr("settings.backend.health", locale: settings.language)) {
                healthMessage = backendHealthCheck()
            }

            if !healthMessage.isEmpty {
                Text(healthMessage).font(.caption)
            }

            Button(L10n.tr("settings.backend.match_python", locale: settings.language)) {
                launchBackendPythonMatcher()
            }

            Button(L10n.tr("settings.backend.install", locale: settings.language)) {
                launchBackendInstaller()
            }

            if !installMessage.isEmpty {
                Text(installMessage)
                    .font(.caption)
                    .foregroundStyle(installMessageIsError ? Color.red : Color.secondary)
            }

            Button(L10n.tr("settings.reset", locale: settings.language), role: .destructive) {
                settings.resetToDefaults()
            }
        }
    }

    private func launchBackendInstaller() {
        guard let scriptURL = resolveBackendInstallerScriptURL() else {
            installMessage = L10n.tr("settings.backend.install.missing", locale: settings.language)
            installMessageIsError = true
            return
        }

        if !FileManager.default.isExecutableFile(atPath: scriptURL.path) {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        }

        if NSWorkspace.shared.open(scriptURL) {
            installMessage = L10n.tr("settings.backend.install.launched", locale: settings.language)
            installMessageIsError = false
        } else {
            installMessage = L10n.tr("settings.backend.install.failed", locale: settings.language)
            installMessageIsError = true
        }
    }

    private func launchBackendPythonMatcher() {
        guard let scriptURL = resolveBackendPythonMatcherScriptURL() else {
            installMessage = L10n.tr("settings.backend.match_python.missing", locale: settings.language)
            installMessageIsError = true
            return
        }

        if !FileManager.default.isExecutableFile(atPath: scriptURL.path) {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        }

        if NSWorkspace.shared.open(scriptURL) {
            installMessage = L10n.tr("settings.backend.match_python.launched", locale: settings.language)
            installMessageIsError = false
        } else {
            installMessage = L10n.tr("settings.backend.match_python.failed", locale: settings.language)
            installMessageIsError = true
        }
    }

    private func resolveBackendInstallerScriptURL() -> URL? {
        let fm = FileManager.default

        let bundledPath = Bundle.main.resourceURL?
            .appendingPathComponent("PythonBackend")
            .appendingPathComponent("install_backend_deps.command")
        if let bundledPath, fm.fileExists(atPath: bundledPath.path) {
            return bundledPath
        }

        let workspaceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            workspaceRoot.appendingPathComponent("scripts/install_backend_deps.command"),
            workspaceRoot.appendingPathComponent("Resources/PythonBackend/install_backend_deps.command"),
        ]

        return candidates.first(where: { fm.fileExists(atPath: $0.path) })
    }

    private func resolveBackendPythonMatcherScriptURL() -> URL? {
        let fm = FileManager.default

        let bundledPath = Bundle.main.resourceURL?
            .appendingPathComponent("PythonBackend")
            .appendingPathComponent("match_backend_python.command")
        if let bundledPath, fm.fileExists(atPath: bundledPath.path) {
            return bundledPath
        }

        let workspaceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            workspaceRoot.appendingPathComponent("scripts/match_backend_python.command"),
            workspaceRoot.appendingPathComponent("Resources/PythonBackend/match_backend_python.command"),
        ]

        return candidates.first(where: { fm.fileExists(atPath: $0.path) })
    }
}
