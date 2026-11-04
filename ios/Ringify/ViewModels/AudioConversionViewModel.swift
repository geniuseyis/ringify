import Foundation
import OSLog
import RingifyCore
import SwiftUI

@MainActor
final class AudioConversionViewModel: ObservableObject {
    @Published private(set) var sourceURL: URL?
    @Published var filename = ""
    @Published var format: AudioConversionFormat = .wav
    @Published private(set) var result: ConvertedAudio?
    @Published private(set) var isWorking = false
    @Published var error: String?
    private let service: any AudioConversionService
    private var task: Task<Void, Never>?
    private var generation = 0

    init(service: any AudioConversionService) { self.service = service }
    func select(_ url: URL) {
        cancel()
        clearResult()
        sourceURL = url
        filename = RingtoneRules().safeFilename(from: url.deletingPathExtension().lastPathComponent)
        error = nil
    }
    func start() {
        guard !isWorking, let sourceURL else { return }
        clearResult(); error = nil; isWorking = true; generation += 1
        let token = generation, selectedFormat = format, name = filename
        task = Task { [weak self, service] in
            do {
                let output = try await service.convert(sourceURL: sourceURL, format: selectedFormat, filename: name)
                guard let self, !Task.isCancelled, token == self.generation else {
                    try await service.discard(output)
                    return
                }
                self.result = output
                self.isWorking = false
                self.task = nil
            } catch {
                guard let self, token == self.generation else { return }
                self.isWorking = false; self.task = nil
                if !(error is CancellationError) { self.error = error.localizedDescription }
            }
        }
    }
    func cancel() { generation += 1; task?.cancel(); task = nil; isWorking = false }
    func dispose() { cancel(); clearResult() }
    private func clearResult() {
        guard let previous = result else { return }
        result = nil
        Task { [weak self, service] in
            do { try await service.discard(previous) }
            catch {
                self?.error = error.localizedDescription
                Logger(subsystem: "com.ringify.app", category: "conversion").error("Temporary output cleanup failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }
}
