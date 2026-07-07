import Foundation
import Observation

/// A persistent quick-scratchpad shown in the notch.
@Observable
@MainActor
final class NotesModel {
    var text: String {
        didSet { UserDefaults.standard.set(text, forKey: "quickNote") }
    }

    init() {
        text = UserDefaults.standard.string(forKey: "quickNote") ?? ""
    }
}
