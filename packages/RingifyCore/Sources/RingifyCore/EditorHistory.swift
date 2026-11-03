import Foundation

public struct EditorSnapshot: Equatable, Sendable {
    public var selection: EditSelection
    public var effects: AudioEffectSettings

    public init(selection: EditSelection, effects: AudioEffectSettings) {
        self.selection = selection
        self.effects = effects
    }
}

public struct EditorHistory: Sendable {
    private(set) public var current: EditorSnapshot
    private var undoStack: [EditorSnapshot]
    private var redoStack: [EditorSnapshot]
    private let limit: Int

    public init(initial: EditorSnapshot, limit: Int = 50) {
        current = initial
        undoStack = []
        redoStack = []
        self.limit = max(1, limit)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public mutating func commit(_ snapshot: EditorSnapshot) {
        guard snapshot != current else { return }
        undoStack.append(current)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        current = snapshot
        redoStack.removeAll(keepingCapacity: true)
    }

    @discardableResult
    public mutating func undo() -> EditorSnapshot? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        current = previous
        return current
    }

    @discardableResult
    public mutating func redo() -> EditorSnapshot? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        current = next
        return current
    }

    public mutating func reset(to snapshot: EditorSnapshot) {
        current = snapshot
        undoStack.removeAll(keepingCapacity: true)
        redoStack.removeAll(keepingCapacity: true)
    }
}
