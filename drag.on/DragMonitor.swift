import Cocoa

/// Monitors mouse position at 60Hz using a timer. During left-button drags,
/// feeds positions to ShakeDetector — but ONLY when an actual file drag is
/// happening (not a window drag).
class DragMonitor {

    let shakeDetector = ShakeDetector()

    private var pollTimer: DispatchSourceTimer?
    private var wasButtonDown = false

    // MARK: - Lifecycle

    func startMonitoring() {
        stopMonitoring()

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16)) // ~60Hz
        timer.setEventHandler { [weak self] in
            self?.pollMouseState()
        }
        timer.resume()
        pollTimer = timer

        print("DragMonitor: Started polling at 60Hz")
    }

    func stopMonitoring() {
        pollTimer?.cancel()
        pollTimer = nil
        shakeDetector.reset()
        print("DragMonitor: Stopped polling")
    }

    // MARK: - Polling

    private func pollMouseState() {
        let isButtonDown = CGEventSource.buttonState(
            .combinedSessionState,
            button: .left
        )

        let mouseLocation = NSEvent.mouseLocation

        if isButtonDown {
            // Only feed to shake detector if a FILE drag is active
            // (not a window drag, text selection, etc.)
            if isFileDragActive() {
                shakeDetector.recordMousePosition(mouseLocation)
            }
        } else if wasButtonDown {
            shakeDetector.reset()
        }

        wasButtonDown = isButtonDown
    }

    // MARK: - File Drag Detection

    /// Check if the system drag pasteboard contains file URLs.
    /// During Finder file drags, this pasteboard is populated.
    /// During window drags, it's empty.
    private func isFileDragActive() -> Bool {
        let dragPasteboard = NSPasteboard(name: .drag)
        return dragPasteboard.canReadObject(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
    }

    deinit {
        stopMonitoring()
    }
}
