import XCTest
@testable import GhosttyTerminal

/// Regression coverage for the synthesized link-activation click: a touch
/// tap has no hardware modifier key, so Skerry emulates Command to trigger
/// Ghostty's link check. When the remote program has captured the mouse
/// (tmux, vim, full-screen coding-agent CLIs), a plain click is forwarded to
/// that program instead of being checked against the link table, so Shift —
/// the same local-override signal already used for touch text selection
/// under mouse capture — must be added to reach Ghostty's own handling.
final class TerminalInputModifiersTests: XCTestCase {
    func testLinkActivationAddsSuperOnlyWhenMouseIsNotCaptured() {
        XCTAssertEqual(
            TerminalInputModifiers.linkActivation(isMouseCaptured: false),
            .super_
        )
    }

    func testLinkActivationAddsShiftToBypassCaptureWhenMouseIsCaptured() {
        let mods = TerminalInputModifiers.linkActivation(isMouseCaptured: true)
        XCTAssertTrue(mods.contains(.super_))
        XCTAssertTrue(mods.contains(.shift))
    }
}
