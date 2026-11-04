import Foundation
import RingifyCore
import UniformTypeIdentifiers

actor SecureMediaImportService: MediaImportService {
    private let directories: AppDirectories
    private let fileManager = FileManager.default

    init(directories: AppDirectories) {
        self.directories = directories
    }

    func importMedia(from sourceURL: URL, kind: MediaSourceKind) async throws -> ImportedMedia {
        try Task.checkCancellation()
        guard sourceURL.isFileURL else { throw RingifyError.unauthorizedRemoteHost }

        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw RingifyError.fileNotFound(sourceURL)
        }
        let attributes = try sourceURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard attributes.isRegularFile == true, attributes.isSymbolicLink != true,
              let size = attributes.fileSize, size > 0, size <= 512 * 1_024 * 1_024 else {
            throw RingifyError.corruptMedia
        }
        try validateType(of: sourceURL, kind: kind)
        try directories.prepare()
        try verifyCapacity(for: sourceURL, destinationDirectory: directories.imports)

        let filename = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension.lowercased()
        let destination = directories.uniqueURL(
            in: directories.imports,
            filename: filename,
            extension: fileExtension
        )
        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
            try Task.checkCancellation()
        } catch let error as CocoaError where error.code == .fileWriteOutOfSpace {
            try? fileManager.removeItem(at: destination)
            throw RingifyError.insufficientStorage(requiredBytes: fileSize(at: sourceURL))
        } catch {
            try? fileManager.removeItem(at: destination)
            throw error
        }
        return ImportedMedia(
            localURL: destination,
            originalFilename: sourceURL.lastPathComponent,
            sourceKind: kind
        )
    }

    private func validateType(of url: URL, kind: MediaSourceKind) throws {
        let fileExtension = url.pathExtension.lowercased()
        guard let type = UTType(filenameExtension: fileExtension) else {
            throw RingifyError.unsupportedFile(extension: fileExtension)
        }
        let isAudio = type.conforms(to: .audio)
        let isVideo = type.conforms(to: .movie) || type.conforms(to: .video)
        let isValid: Bool
        switch kind {
        case .audioFile, .microphoneRecording: isValid = isAudio
        case .photoLibraryVideo, .videoFile: isValid = isVideo
        case .authorizedRemoteMedia: isValid = isAudio || isVideo
        }
        guard isValid else { throw RingifyError.unsupportedFile(extension: fileExtension) }
    }

    private func verifyCapacity(for sourceURL: URL, destinationDirectory: URL) throws {
        let required = fileSize(at: sourceURL)
        let values = try? destinationDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let available = values?.volumeAvailableCapacityForImportantUsage,
           available < required + 20_000_000 {
            throw RingifyError.insufficientStorage(requiredBytes: required)
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }
}

actor RestrictedAuthorizedMediaImportService: AuthorizedMediaImportService {
    private let importService: any MediaImportService
    private let allowedHosts: Set<String>
    private let blockedHosts = ["youtube.com", "youtu.be", "tiktok.com", "instagram.com"]

    init(importService: any MediaImportService, allowedHosts: Set<String> = []) {
        self.importService = importService
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
    }

    func importAuthorizedMedia(from remoteURL: URL) async throws -> ImportedMedia {
        guard remoteURL.scheme?.lowercased() == "https", let host = remoteURL.host?.lowercased() else {
            throw RingifyError.unauthorizedRemoteHost
        }
        guard !blockedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) else {
            throw RingifyError.unauthorizedRemoteHost
        }
        guard allowedHosts.contains(host) else { throw RingifyError.authorizationRequired }

        let (downloadedURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw RingifyError.corruptMedia
        }
        let fileExtension = remoteURL.pathExtension.lowercased()
        guard !fileExtension.isEmpty else { throw RingifyError.unsupportedFile(extension: "") }
        let stagedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        defer { try? FileManager.default.removeItem(at: stagedURL) }
        try FileManager.default.copyItem(at: downloadedURL, to: stagedURL)
        return try await importService.importMedia(from: stagedURL, kind: .authorizedRemoteMedia)
    }
}
