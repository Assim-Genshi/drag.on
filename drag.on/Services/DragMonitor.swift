import Cocoa
import os

/// Monitors mouse position at 60Hz during active file drags.
/// Feeds positions to ShakeDetector to detect the "shake to summon" gesture.
final class DragMonitor {

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

        Logger.dragMonitor.info("Started polling at 60Hz")
    }

    func stopMonitoring() {
        pollTimer?.cancel()
        pollTimer = nil
        shakeDetector.reset()
        Logger.dragMonitor.info("Stopped polling")
    }

    // MARK: - Polling

    private func pollMouseState() {
        let isButtonDown = CGEventSource.buttonState(
            .combinedSessionState,
            button: .left
        )

        let mouseLocation = NSEvent.mouseLocation

        if isButtonDown {
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
