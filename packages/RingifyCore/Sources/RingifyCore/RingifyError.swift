import Foundation

public enum RingifyError: Error, Equatable, Sendable {
    case storageUnavailable(reason: String)
    case unsupportedFile(extension: String)
    case missingAudioTrack
    case corruptMedia
    case permissionDenied
    case insufficientStorage(requiredBytes: Int64?)
    case invalidSelection(SelectionValidationError)
    case invalidFilename(FilenameValidationError)
    case exportFailed(reason: String)
    case exportVerificationFailed
    case cancelled
    case projectNotFound
    case fileNotFound(URL)
    case authorizationRequired
    case unauthorizedRemoteHost
    case purchaseFailed(reason: String)
}

public enum SelectionValidationError: Error, Equatable, Sendable {
    case nonFiniteValue
    case negativeStart
    case endNotAfterStart
    case shorterThanMinimum(minimum: TimeInterval)
    case longerThanMaximum(maximum: TimeInterval)
    case exceedsSourceDuration
}

public enum FilenameValidationError: Error, Equatable, Sendable {
    case empty
    case tooLong(maximum: Int)
    case containsPathSeparator
    case reservedName
}

extension RingifyError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .storageUnavailable(let reason): "Project storage is unavailable: \(reason)"
        case .unsupportedFile(_): "The selected file format is not supported."
        case .missingAudioTrack: "The selected media does not contain an audio track."
        case .corruptMedia: "The selected media is damaged or unreadable."
        case .permissionDenied: "Permission was denied."
        case .insufficientStorage(_): "There is not enough free storage."
        case .invalidSelection(_): "The selected audio range is invalid."
        case .invalidFilename(_): "The filename is invalid."
        case .exportFailed(let reason): "Export failed: \(reason)"
        case .exportVerificationFailed: "The exported file could not be verified."
        case .cancelled: "The operation was cancelled."
        case .projectNotFound: "The project could not be found."
        case .fileNotFound(_): "The media file could not be found."
        case .authorizationRequired: "This source requires explicit authorization."
        case .unauthorizedRemoteHost: "This remote source is not authorized."
        case .purchaseFailed(let reason): "Purchase failed: \(reason)"
        }
    }
}
