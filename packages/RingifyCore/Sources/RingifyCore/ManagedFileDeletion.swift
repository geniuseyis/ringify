import Foundation

/// File changes are staged first and rolled back if metadata cannot commit.
/// Only regular files under explicit application-owned roots are eligible.
public struct ManagedFileDeletion: Sendable {
    private struct JournalEntry: Codable {
        let original: URL
        let stagedName: String
    }
    public struct Batch: Sendable {
        let directory: URL
        let moves: [(original: URL, staged: URL)]
    }
    private let roots: [URL]
    private let trash: URL

    public init(roots: [URL], trash: URL) {
        self.roots = roots.map { $0.standardizedFileURL.resolvingSymlinksInPath() }
        self.trash = trash.standardizedFileURL.resolvingSymlinksInPath()
    }

    public func stage(candidates: [URL], retaining referenced: [URL]) throws -> Batch {
        let manager = FileManager.default
        let retained = Set(referenced.map { $0.standardizedFileURL.resolvingSymlinksInPath() })
        let directory = trash.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var moves: [(original: URL, staged: URL)] = []
        do {
            var planned: [(original: URL, staged: URL)] = []
            for original in Set(candidates) {
                guard original.isFileURL else { continue }
                let resolved = original.standardizedFileURL.resolvingSymlinksInPath()
                guard roots.contains(where: { root in
                    let parent = root.pathComponents
                    return resolved.pathComponents.count > parent.count && resolved.pathComponents.starts(with: parent)
                }),
                      !retained.contains(resolved), manager.fileExists(atPath: original.path) else { continue }
                let values = try resolved.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                let staged = directory.appendingPathComponent(UUID().uuidString)
                planned.append((original, staged))
            }
            let journal = planned.map { JournalEntry(original: $0.original, stagedName: $0.staged.lastPathComponent) }
            try JSONEncoder().encode(journal).write(to: directory.appendingPathComponent("journal.json"), options: .atomic)
            for (original, staged) in planned {
                try manager.moveItem(at: original, to: staged)
                moves.append((original, staged))
            }
            return Batch(directory: directory, moves: moves)
        } catch {
            try rollback(Batch(directory: directory, moves: moves))
            throw error
        }
    }

    public func rollback(_ batch: Batch) throws {
        let manager = FileManager.default
        for move in batch.moves.reversed() {
            try manager.moveItem(at: move.staged, to: move.original)
        }
        try manager.removeItem(at: batch.directory)
    }

    public func commit(_ batch: Batch) throws {
        try FileManager.default.removeItem(at: batch.directory)
    }

    /// After interruption, metadata is the authority: referenced files are
    /// restored, committed deletions are finished. Never overwrite a new file.
    public func recover(retaining referenced: [URL]) throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: trash.path) else { return }
        let retained = Set(referenced.map { $0.standardizedFileURL.resolvingSymlinksInPath() })
        for directory in try manager.contentsOfDirectory(at: trash, includingPropertiesForKeys: [.isDirectoryKey]) {
            guard UUID(uuidString: directory.lastPathComponent) != nil,
                directory.standardizedFileURL == directory.standardizedFileURL.resolvingSymlinksInPath() else { continue }
            guard try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { continue }
            let journalURL = directory.appendingPathComponent("journal.json")
            if !manager.fileExists(atPath: journalURL.path) {
                if try manager.contentsOfDirectory(atPath: directory.path).isEmpty { try manager.removeItem(at: directory) }
                continue
            }
            let entries = try JSONDecoder().decode([JournalEntry].self, from: Data(contentsOf: journalURL))
            for entry in entries {
                let resolved = entry.original.standardizedFileURL.resolvingSymlinksInPath()
                guard entry.original.isFileURL, !entry.stagedName.contains("/"), !entry.stagedName.contains("\\"),
                    UUID(uuidString: entry.stagedName) != nil,
                    roots.contains(where: { resolved.pathComponents.count > $0.pathComponents.count && resolved.pathComponents.starts(with: $0.pathComponents) }) else {
                    throw RingifyError.storageUnavailable(reason: "Invalid pending file deletion journal")
                }
                let staged = directory.appendingPathComponent(entry.stagedName)
                if retained.contains(resolved), manager.fileExists(atPath: staged.path) {
                    guard !manager.fileExists(atPath: entry.original.path) else {
                        throw RingifyError.storageUnavailable(reason: "A recovered audio file conflicts with an existing file")
                    }
                    try manager.moveItem(at: staged, to: entry.original)
                }
            }
            try manager.removeItem(at: directory)
        }
    }
}
