import Foundation

public enum ToolName: String, CaseIterable, Sendable {
    case ffmpeg
    case mp4decrypt
    case mp4box
    case nm3u8dlre

    public var candidates: [String] {
        switch self {
        case .ffmpeg: return ["ffmpeg"]
        case .mp4decrypt: return ["mp4decrypt"]
        case .mp4box: return ["MP4Box", "mp4box"]
        case .nm3u8dlre: return ["N_m3u8DL-RE", "n_m3u8dl-re", "nm3u8dlre"]
        }
    }
}

public enum ToolResolver {
    public static func resolve(
        tool: ToolName,
        overridePath: String,
        bundledRoot: URL?
    ) -> String? {
        if let path = resolvePath(overridePath), !path.isEmpty { return path }

        let candidateNames = tool.candidates
        var searchDirs: [URL] = []

        if let bundledRoot {
            searchDirs.append(bundledRoot)
            searchDirs.append(bundledRoot.appendingPathComponent("macos-arm64"))
            searchDirs.append(bundledRoot.appendingPathComponent("macos"))
        }

        searchDirs.append(URL(fileURLWithPath: "/opt/homebrew/bin"))
        searchDirs.append(URL(fileURLWithPath: "/usr/local/bin"))

        for dir in searchDirs {
            for candidate in candidateNames {
                let full = dir.appendingPathComponent(candidate).path
                if FileManager.default.isExecutableFile(atPath: full) {
                    return full
                }
            }
        }

        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for entry in pathEnv.split(separator: ":") {
            let root = URL(fileURLWithPath: String(entry))
            for candidate in candidateNames {
                let full = root.appendingPathComponent(candidate).path
                if FileManager.default.isExecutableFile(atPath: full) {
                    return full
                }
            }
        }

        return nil
    }

    private static func resolvePath(_ path: String) -> String? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.contains("/") || trimmed.hasPrefix("~") {
            let expanded = NSString(string: trimmed).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return expanded
            }
            return nil
        }

        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for entry in pathEnv.split(separator: ":") {
            let full = URL(fileURLWithPath: String(entry)).appendingPathComponent(trimmed).path
            if FileManager.default.isExecutableFile(atPath: full) {
                return full
            }
        }
        return nil
    }
}
