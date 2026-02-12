import Cocoa

/// Monitors mouse position at 60Hz using a timer. During left-button drags,
/// feeds positions to ShakeDetector. This approach works reliably during Finder
/// drag sessions where NSEvent global monitors don't fire.
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
        // Check if left mouse button is currently held down
        let isButtonDown = CGEventSource.buttonState(
            .combinedSessionState,
            button: .left
        )

        let mouseLocation = NSEvent.mouseLocation

        if isButtonDown && isFileDragSessionActive() {
            // Only track shake when an active drag session contains file URLs
            shakeDetector.recordMousePosition(mouseLocation)
        } else if wasButtonDown {
            shakeDetector.reset()
        }

        wasButtonDown = isButtonDown
    }

    private func isFileDragSessionActive() -> Bool {
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
