import Combine
import Foundation
import RingifyCore

struct AudioSegmentsInput: Equatable, Sendable {
    let projectID: UUID
    let sourceURL: URL
    let sourceDuration: TimeInterval
    let duration: AudioSegmentDuration
    init(_ project: RingtoneProject, duration: AudioSegmentDuration) {
        projectID = project.id; sourceURL = project.sourceURL; sourceDuration = project.sourceDuration; self.duration = duration
    }
}
@MainActor
final class AudioSegmentsViewModel: ObservableObject {
    enum State: Equatable { case idle, running, ready([AudioSegmentSuggestion]), failed }
    @Published private(set) var state: State = .idle
    private let service: any AudioSegmentSuggesting
    private var input: AudioSegmentsInput?
    private var token = UUID()
    private var pending: Task<Void, Never>?
    init(service: any AudioSegmentSuggesting) { self.service = service }
    deinit { pending?.cancel() }
    func update(_ input: AudioSegmentsInput) {
        guard self.input != input else { return }; cancel(); self.input = input
    }
    func cancel() { token = UUID(); pending?.cancel(); pending = nil; state = .idle }
    @discardableResult
    func start(_ input: AudioSegmentsInput) -> Task<Void, Never>? {
        update(input)
        guard state != .running else { return nil }
        guard input.sourceDuration.isFinite, (1...120).contains(input.sourceDuration), input.sourceURL.isFileURL else {
            state = .failed; return nil
        }
        cancel(); state = .running
        let generation = token, service = service
        let task = Task { [weak self] in
            do {
                let result = try await service.suggest(sourceURL: input.sourceURL, duration: input.duration)
                try Task.checkCancellation()
                guard let self, self.token == generation, self.input == input else { return }
                guard self.valid(result, input: input) else { self.state = .failed; self.pending = nil; return }
                self.state = .ready(result); self.pending = nil
            } catch {
                guard let self, self.token == generation else { return }
                self.state = error is CancellationError ? .idle : .failed; self.pending = nil
            }
        }
        pending = task; return task
    }
    func selection(at index: Int, input: AudioSegmentsInput) -> EditSelection? {
        guard self.input == input, case .ready(let result) = state, valid(result, input: input), result.indices.contains(index) else { return nil }
        return result[index].selection
    }
    private func valid(_ result: [AudioSegmentSuggestion], input: AudioSegmentsInput) -> Bool {
        guard result.count <= 3 else { return false }
        let target = min(input.sourceDuration, Double(input.duration.rawValue))
        var previousPower = Double.infinity
        for (index, item) in result.enumerated() {
            guard item.rmsDbFS.isFinite, item.rmsDbFS >= -45 - 1e-6, item.rmsDbFS <= previousPower + 1e-8,
                  abs(item.selection.duration - target) <= 1.0 / 8_000,
                  (try? ValidateSelectionUseCase()(item.selection, sourceDuration: input.sourceDuration + 1.0 / 8_000)) != nil,
                  result.prefix(index).allSatisfy({ item.selection.end <= $0.selection.start || item.selection.start >= $0.selection.end }) else { return false }
            previousPower = item.rmsDbFS
        }
        return true
    }
}
