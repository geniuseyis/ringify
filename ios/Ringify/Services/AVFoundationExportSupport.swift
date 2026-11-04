@preconcurrency import AVFoundation
import Foundation
import RingifyCore

final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
}

enum AVFoundationExportSupport {
    static func run(_ session: AVAssetExportSession) async throws {
        // iOS 17 is the deployment floor. The replacement export(to:as:isolation:)
        // requires a newer SDK, so this compatibility bridge is retained until the
        // project moves to that SDK. Cancellation is still propagated explicitly.
        try Task.checkCancellation()
        let box = ExportSessionBox(session)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                box.session.exportAsynchronously {
                    switch box.session.status {
                    case .completed:
                        continuation.resume()
                    case .cancelled:
                        continuation.resume(throwing: CancellationError())
                    case .failed:
                        continuation.resume(throwing: box.session.error ?? RingifyError.exportFailed(reason: "AVFoundation"))
                    default:
                        continuation.resume(throwing: RingifyError.exportFailed(reason: "Unexpected export state"))
                    }
                }
            }
        } onCancel: {
            box.session.cancelExport()
        }
    }
}
