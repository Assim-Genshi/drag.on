import Foundation
import SwiftUI

/// Observable UI state class for managing Drag.on Lair display modes,
/// selection states, and transitions. Completely decoupled from LairStore.
@MainActor
@Observable
final class LairUIState {
    var isManagementPanelActive = false
    var selectedItemIDs = Set<UUID>()
    var isExternalDragActive = false
}
