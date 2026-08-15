@testable import GhosttyTerminal
import Testing

struct TerminalTouchScrollRoutingTests {
    @Test
    func herdrOwnsScrollWhenMouseCaptureIsUnavailable() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: false,
            prefersRemotePointerInput: true,
            hasHostHandler: true,
            isUncapturedAlternateScreen: true
        ) == .terminal)
    }

    @Test
    func mouseCapturedTerminalOwnsScrolling() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: true,
            hasHostHandler: true,
            isUncapturedAlternateScreen: true
        ) == .terminal)
    }

    @Test
    func codexTouchScrollUsesHostScrollbackInsteadOfCyclingPromptHistory() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: false,
            hasHostHandler: true,
            isUncapturedAlternateScreen: true
        ) == .hostScrollback)
    }

    @Test
    func primaryScreenShellKeepsGhosttyScrollbackWithHostHandler() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: false,
            hasHostHandler: true,
            isUncapturedAlternateScreen: false
        ) == .terminal)
    }

    @Test
    func terminalOwnsScrollingWithoutHostHandler() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: false,
            hasHostHandler: false,
            isUncapturedAlternateScreen: true
        ) == .terminal)
    }
}
