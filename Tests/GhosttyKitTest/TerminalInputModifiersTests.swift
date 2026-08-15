import GhosttyKit
import XCTest
@testable import GhosttyTerminal

/// Regression coverage for the synthesized single-tap click: a touch tap has
/// no hardware modifier key, so an uncaptured tap emulates Command to trigger
/// Ghostty's link check — a plain tap has no other use there. When the remote
/// program has captured the mouse (tmux, vim, full-screen coding-agent CLIs),
/// the tap must forward unmodified so the remote program can position its own
/// cursor from the click, matching AppKit's real-modifier mouseDown parity.
/// A deliberately armed Command accessory is different: it requests local
/// link activation and must not also forward an ambiguous plain click.
/// A prior version always added Command (plus Shift when captured), which
/// made click-to-position-cursor unreachable in any mouse-aware remote TUI.
final class TerminalInputModifiersTests: XCTestCase {
    func testSingleTapClickEmulatesCommandWhenMouseIsNotCaptured() {
        let plan = TerminalInputModifiers.singleTapClickPlan(isMouseCaptured: false)

        XCTAssertEqual(plan.modifiers, .super_)
        XCTAssertTrue(plan.refreshesLinkState)
    }

    func testSingleTapClickForwardsPlainClickWhenMouseIsCaptured() {
        let plan = TerminalInputModifiers.singleTapClickPlan(isMouseCaptured: true)

        XCTAssertEqual(plan.modifiers, [])
        XCTAssertFalse(plan.refreshesLinkState)
    }

    /// Regression: herdr's navigation stopped responding to taps whenever its
    /// mouse-capture flag was unavailable, because Skerry synthesized a local
    /// Command-click instead of forwarding the plain click to herdr.
    func testHerdrForwardsPlainClickWhenMouseCaptureIsUnavailable() {
        let plan = TerminalInputModifiers.singleTapClickPlan(
            isMouseCaptured: false,
            prefersRemotePointerInput: true
        )

        XCTAssertEqual(plan.modifiers, [])
        XCTAssertFalse(plan.refreshesLinkState)
    }

    /// OpenCode captures mouse input. Command alone never makes Ghostty scan
    /// for a local link in that state; Shift must bypass capture while Command
    /// requests activation, and a same-coordinate retry must refresh hover.
    func testCommandArmedTapOpensLinkInsideMouseCapturedOpenCodeTerminal() {
        let plan = TerminalInputModifiers.singleTapClickPlan(
            isMouseCaptured: true,
            explicitlyActivatesLink: true
        )

        XCTAssertEqual(plan.modifiers, [.shift, .super_])
        XCTAssertTrue(plan.refreshesLinkState)
    }

    func testOpenURLActionIsClaimedSoGhosttyCannotBypassHostURLPolicy() {
        XCTAssertTrue(terminalControllerHandlesAction(GHOSTTY_ACTION_OPEN_URL))
        XCTAssertFalse(terminalControllerHandlesAction(GHOSTTY_ACTION_MOUSE_OVER_LINK))
    }
}
