import Cocoa
import os

/// Event-driven drag monitor using a 3-state machine.
///
/// Replaces the previous 60Hz polling architecture with passive `NSEvent`
/// global/local monitors. Zero CPU overhead when idle — only activates
/// gesture tracking after confirming the drag pasteboard contains a
/// supported payload (file URL, web URL, image, or URL-parseable string).
///
/// Feeds validated drag coordinates to ``ShakeDetector`` to detect the
/// "shake to summon" gesture.
@MainActor
final class DragMonitor {

    let shakeDetector = ShakeDetector()
    var onDragEnded: (() -> Void)?

    // MARK: - State Machine

    /// The three phases of drag tracking.
    ///
    /// - `idle`: No active drag, or drag has no supported payload. Zero CPU work.
    /// - `validating`: First `leftMouseDragged` received; checking the pasteboard.
    /// - `tracking`: Pasteboard confirmed a supported payload. Feeding coordinates
    ///   to ``ShakeDetector`` on every subsequent drag event.
    private enum State {
        case idle
        case validating
        case tracking
    }

    private var state: State = .idle
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var lastChangeCount = -1

    // MARK: - Lifecycle

    func startMonitoring() {
        stopMonitoring()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleEvent(event)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleEvent(event)
            }
            return event
        }

        Logger.dragMonitor.info("Event-driven drag monitoring started (3-state machine).")
    }

    func stopMonitoring() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = localMonitor  { NSEvent.removeMonitor(m); localMonitor  = nil }
        transitionToIdle()
        Logger.dragMonitor.info("Drag monitoring stopped.")
    }

    // MARK: - Event Routing

    private func handleEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDragged:
            handleDrag()
        case .leftMouseUp:
            handleMouseUp()
        default:
            break
        }
    }

    private func handleDrag() {
        switch state {
        case .idle:
            // First drag event — transition to validating.
            // We do NOT assume a payload exists yet.
            state = .validating

            if validatePasteboard() {
                // Pasteboard contains a supported payload → enter tracking
                state = .tracking
                shakeDetector.recordMousePosition(NSEvent.mouseLocation)
            } else {
                // No supported payload (window resize, text select, etc.)
                // Drop back to idle — ignore all subsequent drags until mouse-up.
                state = .idle
            }

        case .validating:
            // Resolved synchronously in the .idle branch above.
            // Should not arrive here, but handle gracefully.
            break

        case .tracking:
            // Confirmed payload drag — feed the coordinate to the gesture detector.
            shakeDetector.recordMousePosition(NSEvent.mouseLocation)
        }
    }

    private func handleMouseUp() {
        let wasTracking = (state == .tracking)
        transitionToIdle()
        if wasTracking {
            onDragEnded?()
        }
    }

    private func transitionToIdle() {
        state = .idle
        shakeDetector.reset()
    }

    // MARK: - Pasteboard Validation

    /// Returns `true` only if the drag pasteboard contains a supported payload type:
    /// - File URL (local files from Finder, desktop, etc.)
    /// - Web URL (http/https links from browsers)
    /// - Image data (dragged images without a file URL)
    /// - String parseable as a URL (e.g. Pinterest drags plain text)
    ///
    /// Called exactly once per drag session on the first `.leftMouseDragged` event.
    /// If it returns `false`, the monitor stays `.idle` for the rest of the session.
    private func validatePasteboard() -> Bool {
        let pb = NSPasteboard(name: .drag)
        let changeCount = pb.changeCount

        // Fast path: pasteboard hasn't changed since last check
        guard changeCount != lastChangeCount else { return false }
        lastChangeCount = changeCount

        // 1. File URLs (highest priority — direct file drags from Finder, desktop, etc.)
        if pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) {
            return true
        }

        // 2. Web URLs (http/https links dragged from browsers)
        if pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: false]) {
            return true
        }

        // 3. Image data (e.g. dragging an image directly from a web page)
        if pb.canReadObject(forClasses: [NSImage.self], options: nil) {
            return true
        }

        // 4. Strings that parse as URLs (Pinterest, some web apps)
        if let strings = pb.readObjects(forClasses: [NSString.self], options: nil) as? [String] {
            let hasURL = strings.contains { str in
                guard let url = URL(string: str) else { return false }
                return url.scheme == "http" || url.scheme == "https"
            }
            if hasURL { return true }
        }

        return false
    }

}
