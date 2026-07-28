import XCTest
@testable import GhosttyTerminal

/// Regression coverage for the synthesized single-tap click: a touch tap has
/// no hardware modifier key, so an uncaptured tap emulates Command to trigger
/// Ghostty's link check — a plain tap has no other use there. When the remote
/// program has captured the mouse (tmux, vim, full-screen coding-agent CLIs),
/// the tap must forward unmodified so the remote program can position its own
/// cursor from the click, matching AppKit's real-modifier mouseDown parity.
/// A prior version always added Command (plus Shift when captured), which
/// made click-to-position-cursor unreachable in any mouse-aware remote TUI.
final class TerminalInputModifiersTests: XCTestCase {
    func testSingleTapClickEmulatesCommandWhenMouseIsNotCaptured() {
        XCTAssertEqual(
            TerminalInputModifiers.singleTapClick(isMouseCaptured: false),
            .super_
        )
    }

    func testSingleTapClickForwardsPlainClickWhenMouseIsCaptured() {
        XCTAssertEqual(
            TerminalInputModifiers.singleTapClick(isMouseCaptured: true),
            []
        )
    }
}
