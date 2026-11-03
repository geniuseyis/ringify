import Foundation

/// Export results belong to a specific project edit, never to the application.
public struct ProjectExportState: Sendable {
    private struct Identity: Equatable, Sendable {
        let id: UUID
        let sourceURL: URL
        let name: String
        let selection: EditSelection
        let effects: AudioEffectSettings
        init(_ project: RingtoneProject) {
            id = project.id; sourceURL = project.sourceURL; name = project.name
            selection = project.selection; effects = project.effects
        }
    }
    private var identity: Identity?
    private var token: UUID?
    public private(set) var result: ExportedRingtone?

    public init() {}

    @discardableResult public mutating func begin(for project: RingtoneProject) -> UUID {
        let newToken = UUID()
        identity = Identity(project)
        token = newToken
        result = nil
        return newToken
    }

    public func accepts(_ project: RingtoneProject?, token expected: UUID) -> Bool {
        guard let project else { return false }
        return token == expected && identity == Identity(project)
    }

    @discardableResult public mutating func complete(_ output: ExportedRingtone, for project: RingtoneProject?, token: UUID) -> Bool {
        guard accepts(project, token: token) else { return false }
        result = output
        return true
    }

    @discardableResult public mutating func invalidate(for project: RingtoneProject?) -> Bool {
        guard let project, identity == Identity(project) else { reset(); return true }
        return false
    }

    public mutating func reset() {
        identity = nil
        token = nil
        result = nil
    }
}
