import Cocoa
import os

/// Monitors mouse position at 60Hz during active file drags.
/// Feeds positions to ShakeDetector to detect the "shake to summon" gesture.
///
/// Runs entirely on a background queue to avoid blocking the main thread
/// with IPC calls to NSPasteboard.
final class DragMonitor {

    let shakeDetector = ShakeDetector()
    var onDragEnded: (@Sendable @MainActor () -> Void)?

    private var pollTimer: DispatchSourceTimer?
    private var lastChangeCount = -1
    private var cachedIsFileDragActive = false
    private var wasButtonDown = false

    /// High-priority background queue for polling — keeps main thread free.
    private let pollQueue = DispatchQueue(
        label: "com.yokai.drag-on.drag-monitor",
        qos: .userInteractive
    )

    // MARK: - Lifecycle

    func startMonitoring() {
        stopMonitoring()

        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16)) // ~60Hz
        timer.setEventHandler { [weak self] in
            self?.pollMouseState()
        }
        timer.resume()
        pollTimer = timer

        Logger.dragMonitor.info("Started polling at 60Hz (background queue)")
    }

    func stopMonitoring() {
        pollTimer?.cancel()
        pollTimer = nil
        shakeDetector.reset()
        Logger.dragMonitor.info("Stopped polling")
    }

    // MARK: - Polling (runs on pollQueue)

    private func pollMouseState() {
        // CGEventSource.buttonState and NSEvent.mouseLocation are thread-safe
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
            if let callback = onDragEnded {
                Task { @MainActor in
                    callback()
                }
            }
        }

        wasButtonDown = isButtonDown
    }

    // MARK: - File Drag Detection (runs on pollQueue)

    /// Check if the system drag pasteboard contains file URLs or web URLs.
    /// Runs the actual pasteboard queries on the main thread since NSPasteboard
    /// is not thread-safe, but mutates cached state on the background queue to
    /// avoid Sendable/isolation warnings.
    private func isFileDragActive() -> Bool {
        // Retrieve changeCount from the main thread without capturing self
        let changeCount = DispatchQueue.main.sync {
            return NSPasteboard(name: .drag).changeCount
        }
        
        if changeCount != lastChangeCount {
            lastChangeCount = changeCount
            
            // Query pasteboard types on the main thread
            cachedIsFileDragActive = DispatchQueue.main.sync {
                let dragPasteboard = NSPasteboard(name: .drag)
                let canReadFileURL = dragPasteboard.canReadObject(
                    forClasses: [NSURL.self],
                    options: [.urlReadingFileURLsOnly: true]
                )
                let canReadWebURL = dragPasteboard.canReadObject(
                    forClasses: [NSURL.self],
                    options: [.urlReadingFileURLsOnly: false]
                )
                return canReadFileURL || canReadWebURL
            }
        }
        
        return cachedIsFileDragActive
    }

    deinit {
        stopMonitoring()
    }
}
