import XCTest
@testable import RingifyCore

final class EditorHistoryTests: XCTestCase {
    func testUndoRedoAndNewCommit() {
        let initial = EditorSnapshot(
            selection: EditSelection(start: 0, end: 10),
            effects: .neutral
        )
        var history = EditorHistory(initial: initial)
        let second = EditorSnapshot(
            selection: EditSelection(start: 2, end: 12),
            effects: AudioEffectSettings(volume: 0.8)
        )
        history.commit(second)

        XCTAssertTrue(history.canUndo)
        XCTAssertEqual(history.undo(), initial)
        XCTAssertTrue(history.canRedo)
        XCTAssertEqual(history.redo(), second)

        _ = history.undo()
        history.commit(EditorSnapshot(
            selection: EditSelection(start: 1, end: 9),
            effects: .neutral
        ))
        XCTAssertFalse(history.canRedo)
    }

    func testHistoryLimitDropsOldestSnapshot() {
        let initial = EditorSnapshot(selection: EditSelection(start: 0, end: 5), effects: .neutral)
        var history = EditorHistory(initial: initial, limit: 2)
        history.commit(EditorSnapshot(selection: EditSelection(start: 1, end: 6), effects: .neutral))
        history.commit(EditorSnapshot(selection: EditSelection(start: 2, end: 7), effects: .neutral))
        history.commit(EditorSnapshot(selection: EditSelection(start: 3, end: 8), effects: .neutral))

        XCTAssertNotNil(history.undo())
        XCTAssertNotNil(history.undo())
        XCTAssertNil(history.undo())
    }
}
