import Foundation

public struct BackendLaunchContext: Sendable {
    public let pythonExecutable: String
    public let launcherScript: String

    public init(pythonExecutable: String, launcherScript: String) {
        self.pythonExecutable = pythonExecutable
        self.launcherScript = launcherScript
    }
}

@MainActor
public final class BackendBridgeService: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var logs: [ParsedLogLine] = []
    @Published public private(set) var detectedFiles: [String] = []
    @Published public private(set) var completedURLCount = 0
    @Published public private(set) var totalURLCount = 0
    @Published public private(set) var lastError: String?

    private var process: Process?

    public init() {}

    public func resetLogs() {
        logs.removeAll()
        detectedFiles.removeAll()
    }

    public func start(
        urls: [String],
        cookiesPath: String,
        outputPath: String,
        config: DownloadConfig,
        launch: BackendLaunchContext
    ) throws {
        guard !isRunning else { return }

        resetLogs()
        lastError = nil
        totalURLCount = urls.count
        completedURLCount = 0

        let args = CLIArgumentBuilder.build(urls: urls, cookiesPath: cookiesPath, outputPath: outputPath, config: config)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: launch.pythonExecutable)
        p.arguments = [launch.launcherScript] + args
        p.environment = buildEnvironment(launch: launch)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        p.standardOutput = stdoutPipe
        p.standardError = stderrPipe

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty { return }
            Task { @MainActor [weak self] in
                self?.ingest(data: data)
            }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty { return }
            Task { @MainActor [weak self] in
                self?.ingest(data: data)
            }
        }

        p.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                guard let self else { return }
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                self.isRunning = false
                if proc.terminationStatus != 0 {
                    self.lastError = "Backend exited with status \(proc.terminationStatus)"
                }
                self.process = nil
            }
        }

        try p.run()
        process = p
        isRunning = true
    }

    public func cancel() {
        guard let process else { return }
        process.terminate()

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            if process.isRunning {
                process.interrupt()
            }
        }
    }

    private func ingest(data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        for line in lines {
            let parsed = LogParser.parse(line)
            logs.append(parsed)
            if let path = parsed.detectedFilePath, !detectedFiles.contains(path) {
                detectedFiles.append(path)
            }
            if let progress = LogParser.parseProgress(line) {
                completedURLCount = max(completedURLCount, progress.completed)
                totalURLCount = max(totalURLCount, progress.total)
            }
        }
    }

    private func buildEnvironment(launch: BackendLaunchContext) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment

        let launcherDir = URL(fileURLWithPath: launch.launcherScript)
            .deletingLastPathComponent()
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        let candidates: [URL] = [
            launcherDir.appendingPathComponent("site-packages"),
            launcherDir.deletingLastPathComponent().appendingPathComponent("site-packages"),
            cwd.appendingPathComponent("Resources/PythonBackend/site-packages"),
            cwd.appendingPathComponent("site-packages"),
            cwd,
        ]

        var seen = Set<String>()
        var pythonPaths: [String] = []

        for candidate in candidates {
            let path = candidate.path
            if FileManager.default.fileExists(atPath: path), !seen.contains(path) {
                pythonPaths.append(path)
                seen.insert(path)
            }
        }

        if let existing = environment["PYTHONPATH"], !existing.isEmpty {
            for entry in existing.split(separator: ":").map(String.init) where !entry.isEmpty && !seen.contains(entry) {
                pythonPaths.append(entry)
                seen.insert(entry)
            }
        }

        if !pythonPaths.isEmpty {
            environment["PYTHONPATH"] = pythonPaths.joined(separator: ":")
        }

        return environment
    }
}
