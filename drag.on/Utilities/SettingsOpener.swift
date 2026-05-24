import SwiftUI

/// Utility class to bridge programmatic opening of SwiftUI settings from AppKit (AppDelegate).
@MainActor
final class SettingsOpener: ObservableObject {
    static let shared = SettingsOpener()
    
    private var openSettingsAction: (() -> Void)?
    
    func register(action: @escaping () -> Void) {
        self.openSettingsAction = action
    }
    
    func openSettings() {
        if let action = openSettingsAction {
            action()
        } else {
            // Fallback: if not registered yet, try legacy selector
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }
}
