import Foundation
import RingifyCore

struct AppDirectories: Sendable {
    private let rootOverride: URL?
    init(root: URL? = nil) { rootOverride = root }
    private var fileManager: FileManager { .default }

    var root: URL {
        if let rootOverride { return rootOverride }
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Ringify", isDirectory: true)
    }

    var imports: URL { root.appendingPathComponent("Imports", isDirectory: true) }
    var exports: URL { root.appendingPathComponent("Exports", isDirectory: true) }
    var recordings: URL { root.appendingPathComponent("Recordings", isDirectory: true) }

    func prepare() throws {
        for directory in [root, imports, exports, recordings] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func temporaryURL(extension fileExtension: String) -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
    }

    func uniqueURL(in directory: URL, filename: String, extension fileExtension: String) -> URL {
        let base = RingtoneRules().safeFilename(from: filename)
        var candidate = directory.appendingPathComponent(base).appendingPathExtension(fileExtension)
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(base) \(suffix)").appendingPathExtension(fileExtension)
            suffix += 1
        }
        return candidate
    }
}
