import SwiftUI

@main
struct AppleMusicDownloaderApp: App {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var backend = BackendBridgeService()
    @StateObject private var downloadVM = DownloadFeatureViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(
                settings: settings,
                backend: backend,
                downloadVM: downloadVM,
                launchContext: launchContext,
                backendHealthCheck: backendHealthCheck
            )
            .environment(\.locale, Locale(identifier: settings.language.localeIdentifier))
            .frame(minWidth: 1000, minHeight: 700)
        }
        .defaultSize(width: 1120, height: 760)
    }

    private var launchContext: BackendLaunchContext {
        let bundleRoot = Bundle.main.resourceURL
        let workspaceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Resources")

        let pythonBundlePath = bundleRoot?
            .appendingPathComponent("PythonBackend")
            .appendingPathComponent("python3")
            .path
        let pythonWorkspacePath = workspaceRoot
            .appendingPathComponent("PythonBackend")
            .appendingPathComponent("python3")
            .path

        let launcherBundlePath = bundleRoot?
            .appendingPathComponent("PythonBackend")
            .appendingPathComponent("launcher.py")
            .path
        let launcherWorkspacePath = workspaceRoot
            .appendingPathComponent("PythonBackend")
            .appendingPathComponent("launcher.py")
            .path

        let python = FileManager.default.fileExists(atPath: pythonBundlePath ?? "") ? (pythonBundlePath ?? "") :
            (FileManager.default.fileExists(atPath: pythonWorkspacePath) ? pythonWorkspacePath : "/usr/bin/python3")
        let launcher = FileManager.default.fileExists(atPath: launcherBundlePath ?? "") ? (launcherBundlePath ?? "") : launcherWorkspacePath

        return BackendLaunchContext(
            pythonExecutable: python,
            launcherScript: launcher
        )
    }

    private func backendHealthCheck() -> String {
        let fm = FileManager.default
        let ctx = launchContext

        guard fm.fileExists(atPath: ctx.pythonExecutable) else {
            return "Python executable missing: \(ctx.pythonExecutable)"
        }
        guard fm.fileExists(atPath: ctx.launcherScript) else {
            return "Backend launcher missing: \(ctx.launcherScript)"
        }
        return "Backend OK"
    }
}

struct RootView: View {
    @ObservedObject var settings: AppSettingsStore
    @ObservedObject var backend: BackendBridgeService
    @ObservedObject var downloadVM: DownloadFeatureViewModel

    let launchContext: BackendLaunchContext
    let backendHealthCheck: () -> String

    private enum Route: String, CaseIterable, Identifiable {
        case download
        case settings

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .download: return "arrow.down.circle"
            case .settings: return "gearshape"
            }
        }

        func title(language: AppLanguage) -> String {
            switch self {
            case .download:
                return L10n.tr("nav.download", locale: language)
            case .settings:
                return L10n.tr("nav.settings", locale: language)
            }
        }
    }

    @State private var selection: Route? = .download

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Route.allCases) { route in
                    Label(route.title(language: settings.language), systemImage: route.icon)
                        .tag(route)
                }
            }
            .listStyle(.sidebar)
        } detail: {
            switch selection ?? .download {
            case .download:
                DownloadFeatureView(
                    settings: settings,
                    backend: backend,
                    viewModel: downloadVM,
                    launchContext: launchContext
                )
            case .settings:
                SettingsFeatureView(
                    settings: settings,
                    bundledToolsURL: Bundle.main.resourceURL?.appendingPathComponent("Tools"),
                    backendHealthCheck: backendHealthCheck
                )
            }
        }
        .navigationTitle(L10n.tr("app.title", locale: settings.language))
        .task {
            if selection == nil {
                selection = .download
            }
            autoDetectToolsIfNeeded()
        }
    }

    private func autoDetectToolsIfNeeded() {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Tools")

        if settings.config.toolPaths.ffmpeg.isEmpty {
            settings.config.toolPaths.ffmpeg = ToolResolver.resolve(tool: .ffmpeg, overridePath: "", bundledRoot: bundled) ?? ""
        }
        if settings.config.toolPaths.mp4decrypt.isEmpty {
            settings.config.toolPaths.mp4decrypt = ToolResolver.resolve(tool: .mp4decrypt, overridePath: "", bundledRoot: bundled) ?? ""
        }
        if settings.config.toolPaths.mp4box.isEmpty {
            settings.config.toolPaths.mp4box = ToolResolver.resolve(tool: .mp4box, overridePath: "", bundledRoot: bundled) ?? ""
        }
        if settings.config.toolPaths.nm3u8dlre.isEmpty {
            settings.config.toolPaths.nm3u8dlre = ToolResolver.resolve(tool: .nm3u8dlre, overridePath: "", bundledRoot: bundled) ?? ""
        }
    }
}
