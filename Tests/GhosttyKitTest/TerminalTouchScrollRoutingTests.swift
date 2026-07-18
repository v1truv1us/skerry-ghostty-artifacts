@testable import GhosttyTerminal
import Testing

struct TerminalTouchScrollRoutingTests {
    @Test
    func mouseCapturedTerminalOwnsScrolling() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: true,
            hasHostHandler: true
        ) == .terminal)
    }

    @Test
    func hostCanInterceptScrollingWithoutMouseCapture() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: false,
            hasHostHandler: true
        ) == .undecided)
    }

    @Test
    func terminalOwnsScrollingWithoutHostHandler() {
        #expect(TerminalTouchScrollRouting.initialOwner(
            isMouseCaptured: false,
            hasHostHandler: false
        ) == .terminal)
    }
}
