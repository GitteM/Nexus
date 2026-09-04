import XCTest

/// Tap interactions for the UI suites.
///
/// CI evidence (same commit green in one run, red in another) shows taps
/// that follow a `waitForExistence` can land while the element is still
/// mid-layout/animation on slow runners and silently miss. Every tap in the
/// suites goes through `tapWhenReady`, which waits until the element both
/// exists **and** is hittable before synthesizing the tap.
@MainActor
enum UITestInteraction {
    /// Waits (up to `timeout`) for `element` to exist and be hittable, then
    /// taps it. Returns `true` when the tap was performed.
    @discardableResult
    static func tapWhenReady(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable {
                element.tap()
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }
}
