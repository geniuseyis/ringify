import Foundation
import RingifyCore

@MainActor
enum StudioSelectionPersistence {
    // Accepted means queued (or already identical), not durably saved. The
    // existing AppModel write queue presents asynchronous storage failures.
    static func commit(_ selection: EditSelection, expectedProjectID: UUID, model: AppModel) -> Bool {
        guard let project = model.currentProject, project.id == expectedProjectID else { return false }
        guard case .success = RingtoneRules().validate(selection: selection, sourceDuration: project.sourceDuration) else { return false }
        guard project.selection != selection else { return true }
        return model.updateCurrentProject { $0.selection = selection }
    }
}
