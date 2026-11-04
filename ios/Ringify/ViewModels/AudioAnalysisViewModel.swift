import Combine
import Foundation
import RingifyCore

struct AudioAnalysisInput: Equatable, Sendable {
    let projectID: UUID
    let sourceURL: URL
    let selection: EditSelection

    init(_ project: RingtoneProject) {
        projectID = project.id
        sourceURL = project.sourceURL
        selection = project.selection
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.projectID == rhs.projectID && lhs.sourceURL == rhs.sourceURL
            && lhs.selection.start.bitPattern == rhs.selection.start.bitPattern
            && lhs.selection.end.bitPattern == rhs.selection.end.bitPattern
    }
}

@MainActor
final class AudioAnalysisViewModel: ObservableObject {
    enum State: Equatable {
        case idle, locked, running
        case ready(AudioSignalAnalysis)
        case failed
    }

    @Published private(set) var state: State = .idle
    private let service: any AudioSignalAnalyzing
    private var input: AudioAnalysisInput?
    private var generation = UUID()
    private var task: Task<Void, Never>?

    init(service: any AudioSignalAnalyzing) { self.service = service }
    deinit { task?.cancel() }

    func updateInput(_ project: RingtoneProject) {
        let next = AudioAnalysisInput(project)
        guard input != next else { return }
        cancel()
        input = next
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        state = .idle
    }

    @discardableResult
    func start(_ project: RingtoneProject, hasVerifiedPro: Bool) -> Task<Void, Never>? {
        updateInput(project)
        guard hasVerifiedPro else { cancel(); state = .locked; return nil }
        guard state != .running else { return nil }
        cancel()
        do { _ = try ValidateSelectionUseCase()(project.selection, sourceDuration: project.sourceDuration) }
        catch { state = .failed; return nil }
        let request = AudioAnalysisInput(project), token = UUID(), service = self.service
        generation = token
        state = .running
        let pending = Task<Void, Never> { [weak self] in
            do {
                let result = try await service.analyze(sourceURL: request.sourceURL, selection: request.selection)
                try Task.checkCancellation()
                guard let self, self.generation == token, self.input == request else { return }
                guard self.valid(result, for: project) else { self.state = .failed; self.task = nil; return }
                self.state = .ready(result)
                self.task = nil
            } catch {
                guard let self, self.generation == token else { return }
                self.state = error is CancellationError ? .idle : .failed
                self.task = nil
            }
        }
        task = pending
        return pending
    }

    func suggestion(for project: RingtoneProject, hasVerifiedPro: Bool) -> EditSelection? {
        guard hasVerifiedPro, input == AudioAnalysisInput(project), case .ready(let result) = state,
              valid(result, for: project) else { return nil }
        return result.suggestion
    }

    private func valid(_ result: AudioSignalAnalysis, for project: RingtoneProject) -> Bool {
        let tolerance = 1.0 / 8_000
        guard result.selection.start.isFinite, result.selection.end.isFinite,
              abs(result.selection.start - project.selection.start) <= tolerance,
              abs(result.selection.end - project.selection.end) <= tolerance,
              result.peakDbFS?.isFinite != false, result.rmsDbFS?.isFinite != false,
              (result.peakDbFS == nil) == (result.rmsDbFS == nil) else { return false }
        if let peak = result.peakDbFS, let rms = result.rmsDbFS, rms > peak + 1e-8 { return false }
        if result.peakDbFS == nil && result.suggestion != nil { return false }
        var previousEnd = result.selection.start
        for region in result.silentRegions {
            guard region.start.isFinite, region.end.isFinite, region.start >= previousEnd - tolerance,
                  region.end <= result.selection.end + tolerance, region.duration >= 0.3 - tolerance else { return false }
            previousEnd = region.end
        }
        if let suggestion = result.suggestion {
            guard suggestion.start >= project.selection.start - tolerance,
                  suggestion.end <= project.selection.end + tolerance,
                  suggestion.duration < result.selection.duration,
                  (try? ValidateSelectionUseCase()(suggestion, sourceDuration: project.sourceDuration)) != nil else { return false }
        }
        return true
    }
}
