# Drag.on Project Context

This document provides a comprehensive overview of the **Drag.on** project for LLMs. Drag.on is a macOS productivity utility that provides a temporary "shelf" (or "lair") for files, enabling smoother drag-and-drop workflows.

---

## Project Overview
- **Name**: Drag.on
- **Platform**: macOS (Accessory App)
- **Purpose**: A floating drop zone for files. Users can "shake" a file while dragging to summon the shelf, drop files into it, and drag them out later to other applications or folders.
- **Visual Design**: HUD-style translucent window with glassmorphism effects (`.hudWindow` material), a "pile" of file cards with high-quality thumbnails, and smooth animations.
- **Menu Bar**: A "flame" icon in the system menu bar provides quick access to "Show Lair", "Clear Lair", and app settings.

## Technology Stack
- **Language**: Swift
- **UI Frameworks**: 
  - **SwiftUI**: Used for the UI overlay (`ShelfView`) providing labels, buttons, and empty state feedback.
  - **AppKit (Cocoa)**: Used for core window management (`ShelfWindow` as `NSPanel`), global mouse monitoring, native drag-and-drop implementation, and thumbnail rendering.
- **Persistence**: `UserDefaults` with JSON encoding/decoding.
- **File Handling**: Security-scoped bookmarks for persistent file access across app restarts and file moves.

## Project Structure & Component Analysis

### Core Application
- **[drag_onApp.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/drag_onApp.swift)**: Main entry point. Sets up the `AppDelegate` and hides the app from the Dock (`.accessory` policy).
- **AppDelegate**: Manages the lifecycle. Initializes `ShelfStore`, `ShelfWindow`, `DragMonitor`, and the system status item.

### UI Layer (The "Lair")
- **[ShelfWindow.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/ShelfWindow.swift)**:
  - Custom `NSPanel` subclass configured as a borderless, floating, non-activating panel.
  - **Activation Logic**: Overrides `sendEvent` to `activate(ignoringOtherApps: true)` and `makeKeyAndOrderFront` on mouse down, ensuring immediate responsiveness of SwiftUI elements.
  - **Visuals**: Uses `NSVisualEffectView` with a corner radius of 26 and `material = .hudWindow`.
  - **Sub-components**:
    - `DropTargetView`: AppKit view handling incoming file drops (`.fileURL`).
    - `FilePileNSView`: Renders up to 5 file cards as a stacked pile. Handles native `NSDraggingSession` for drag-outs.
    - `FirstMouseHostingView`: A `NSHostingView` subclass that accepts "first mouse" events, allowing clicks to pass through to SwiftUI even when the window isn't focused.
    - `WindowDragHandleView`: An invisible pill at the top for moving the window.
- **[ShelfView.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/ShelfView.swift)**: SwiftUI view defining the user interface (empty state "Drop Artifact here", file count, and close button).

### Interaction & Logic
- **[DragMonitor.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/DragMonitor.swift)**: Monitors global mouse events and pasteboard changes to detect when a file drag is active.
- **[ShakeDetector.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/ShakeDetector.swift)**:
  - Detects rapid horizontal reversals ("shakes") during a drag.
  - **Amplitude Guard**: Rejects movements larger than 150px to prevent triggering during normal window drags.
- **[ShelfStore.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/ShelfStore.swift)**: Observable store managing the list of `FileItem`s. Handles pruning of stale bookmarks on launch.

### Data Model & Storage
- **[FileItem.swift](file:///Users/assimgenshi/Documents/2.coding%20project/drag.on/drag.on/FileItem.swift)**:
  - Represetns a file with `bookmarkData` for persistent access.
  - Generates thumbnails via `QLThumbnailGenerator` and retrieves system icons using `NSWorkspace`.

## Key Interaction Flows
1. **Summoning**: User drags a file -> Performs a quick horizontal shake -> `ShakeDetector` triggers `ShelfWindow.show()`.
2. **Dropping**: User drops files onto the Lair -> `ShelfStore` saves them as `FileItem`s with security bookmarks.
3. **Withdrawing**: User drags a card out -> `FilePileNSView` initiates a `NSDraggingSession` containing **all** files in the lair. Successfully dropping them into a destination **clears** the Lair.
4. **Maintenance**: Lair can be toggled or cleared via the menu bar flame icon.
