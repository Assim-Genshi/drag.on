import Cocoa

/// Detects mouse "shake" gestures — rapid horizontal direction reversals
/// while the mouse button is held down (dragging).
class ShakeDetector {

    /// Called when a shake gesture is detected, with the screen location.
    var onShakeDetected: ((NSPoint) -> Void)?

    // MARK: - Configuration
    private let requiredReversals = 3           // direction changes needed
    private let timeWindow: TimeInterval = 0.5  // max time for reversals
    private let minVelocity: CGFloat = 300.0    // min px/s to count
    private let cooldownInterval: TimeInterval = 1.5
    private let maxAmplitude: CGFloat = 150.0   // max X-range to qualify as a "shake" (not a window drag)

    // MARK: - State
    private struct Sample {
        let position: NSPoint
        let timestamp: TimeInterval
    }

    private var samples: [Sample] = []
    private let maxSamples = 40
    private var lastShakeTime: TimeInterval = 0

    // MARK: - Public

    /// Record a mouse position sample. Call this at a high frequency (~60Hz).
    func recordMousePosition(_ point: NSPoint) {
        let now = ProcessInfo.processInfo.systemUptime

        samples.append(Sample(position: point, timestamp: now))

        // Keep buffer bounded
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }

        // Prune old samples outside the time window
        samples = samples.filter { now - $0.timestamp <= timeWindow }

        checkForShake(at: point, time: now)
    }

    /// Reset all samples (e.g., when mouse button is released).
    func reset() {
        samples.removeAll()
    }

    // MARK: - Detection

    private func checkForShake(at point: NSPoint, time: TimeInterval) {
        guard samples.count >= 4 else { return }

        // Cooldown check
        if time - lastShakeTime < cooldownInterval { return }

        // Amplitude check — reject if the mouse traveled too far horizontally
        // (large movements = window drag, small tight reversals = shake gesture)
        let xValues = samples.map { $0.position.x }
        let xRange = (xValues.max() ?? 0) - (xValues.min() ?? 0)
        if xRange > maxAmplitude { return }

        var reversals = 0
        var lastDirection: CGFloat = 0

        for i in 1..<samples.count {
            let dx = samples[i].position.x - samples[i - 1].position.x
            let dt = samples[i].timestamp - samples[i - 1].timestamp

            guard dt > 0.001 else { continue }

            let velocity = abs(dx / CGFloat(dt))

            guard velocity >= minVelocity else { continue }

            let direction: CGFloat = dx > 0 ? 1.0 : -1.0

            if lastDirection != 0 && direction != lastDirection {
                reversals += 1
            }

            lastDirection = direction
        }

        if reversals >= requiredReversals {
            lastShakeTime = time
            samples.removeAll()
            onShakeDetected?(point)
        }
    }
}
