import Cocoa
import os

/// Detects mouse "shake" gestures using peak/valley extrema tracking.
///
/// Instead of computing noisy instantaneous velocity derivatives, this
/// detector tracks the local peaks and valleys of the X-coordinate stream.
/// A direction reversal is registered when the mouse moves at least
/// ``minSweepDistance`` pixels in the opposite direction from the last
/// extremum — structurally filtering out high-frequency jitter.
///
/// Each completed sweep is validated for amplitude (≤ ``maxSweepDistance``)
/// and duration (≤ ``maxSweepDuration``). Only sweeps that pass both checks
/// count toward the ``requiredReversals`` threshold.
///
/// **Drift-tolerant**: There is no global amplitude cap. The user can shake
/// while moving diagonally across the screen — only individual sweep
/// amplitudes are measured.
@MainActor
final class ShakeDetector {

    /// Called when a shake gesture is detected, with the screen location.
    var onShakeDetected: ((NSPoint) -> Void)?

    // MARK: - Configuration

    /// Number of direction reversals needed to trigger a shake.
    /// Exposed to the Settings UI via the "Shake Sensitivity" slider (range 2–5).
    var requiredReversals: Int = 3

    /// Minimum horizontal distance (px) to establish a direction change.
    /// Anything below this threshold is treated as jitter and ignored.
    var minSweepDistance: CGFloat = 20.0

    /// Maximum horizontal distance (px) for a single sweep to qualify.
    /// Rejects broad, deliberate drags across the screen.
    var maxSweepDistance: CGFloat = 120.0

    /// Maximum time (seconds) for a single sweep to qualify.
    /// Rejects slow, deliberate movements.
    var maxSweepDuration: TimeInterval = 0.25

    /// Cooldown between shake detections.
    var cooldownInterval: TimeInterval = 1.5

    // MARK: - State

    /// Records the position and timestamp of the last detected peak or valley.
    private struct Extremum {
        let x: CGFloat
        let time: TimeInterval
    }

    /// The last detected peak or valley of the X-coordinate stream.
    private var lastExtremum: Extremum?

    /// Current movement direction: `-1` (left), `+1` (right), `0` (unknown).
    private var currentDirection: CGFloat = 0

    /// Timestamps of validated reversals within the active gesture window.
    private var reversalTimes: [TimeInterval] = []

    /// Timestamp of the last successful shake detection (for cooldown).
    private var lastShakeTime: TimeInterval = 0

    // MARK: - Public Interface

    /// Record a mouse position sample. Called by ``DragMonitor`` on every
    /// `.leftMouseDragged` event while in the `.tracking` state.
    func recordMousePosition(_ point: NSPoint) {
        let now = ProcessInfo.processInfo.systemUptime

        // Respect cooldown
        guard now - lastShakeTime >= cooldownInterval else { return }

        guard let extremum = lastExtremum else {
            // First point establishes the starting reference
            lastExtremum = Extremum(x: point.x, time: now)
            return
        }

        let dx = point.x - extremum.x
        let absDx = abs(dx)

        // Only evaluate if the mouse has moved far enough to filter out noise
        guard absDx >= minSweepDistance else { return }

        let newDirection: CGFloat = dx > 0 ? 1.0 : -1.0

        if currentDirection == 0 {
            // Establish initial direction
            currentDirection = newDirection
            lastExtremum = Extremum(x: point.x, time: now)

        } else if newDirection != currentDirection {
            // Direction reversal detected!
            let duration = now - extremum.time

            // Validate the completed sweep: amplitude and speed
            if absDx <= maxSweepDistance && duration <= maxSweepDuration {
                reversalTimes.append(now)

                // Prune reversals outside the active gesture time window
                let windowStart = now - (Double(requiredReversals) * maxSweepDuration)
                reversalTimes.removeAll { $0 < windowStart }

                // Check if the threshold is met
                if reversalTimes.count >= requiredReversals {
                    lastShakeTime = now
                    clearGestureState()
                    onShakeDetected?(point)
                    return
                }
            } else {
                // The sweep was too slow or too broad — reset accumulated reversals
                reversalTimes.removeAll()
            }

            // Update direction and mark the new peak/valley
            currentDirection = newDirection
            lastExtremum = Extremum(x: point.x, time: now)

        } else {
            // Continuing in the same direction — update the extremum to the
            // furthest point reached (tracks the true apex of the sweep).
            if (newDirection > 0 && point.x > extremum.x) ||
               (newDirection < 0 && point.x < extremum.x) {
                lastExtremum = Extremum(x: point.x, time: now)
            }
        }
    }

    /// Reset all gesture state (e.g. when the mouse button is released).
    func reset() {
        clearGestureState()
    }

    /// Manually trigger or extend the shake cooldown.
    /// Called by ``AppDelegate`` when the Lair window hides, preventing
    /// an immediate re-summon on the next drag.
    func startCooldown() {
        lastShakeTime = ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Private

    private func clearGestureState() {
        lastExtremum = nil
        currentDirection = 0
        reversalTimes.removeAll()
    }
}
