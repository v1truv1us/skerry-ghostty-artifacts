@testable import GhosttyTerminal
import Testing

/// Bell and desktop-notification are the two signals a remote program sends
/// specifically to say "notice me." attentionEventCount is the content-free
/// projection of both — a consumer needs to know that a notification was
/// requested, never what it said.
@MainActor
struct TerminalAttentionSignalTests {
    @Test
    func attentionEventCountStartsAtZero() {
        let state = TerminalViewState()
        #expect(state.attentionEventCount == 0)
    }

    @Test
    func bellIncrementsAttentionEventCount() {
        let state = TerminalViewState()

        state.terminalDidRingBell()

        #expect(state.attentionEventCount == 1)
    }

    @Test
    func desktopNotificationIncrementsAttentionEventCount() {
        let state = TerminalViewState()

        state.terminalDidRequestDesktopNotification()

        #expect(state.attentionEventCount == 1)
    }

    @Test
    func repeatedSignalsKeepAdvancingTheCount() {
        let state = TerminalViewState()

        state.terminalDidRingBell()
        state.terminalDidRequestDesktopNotification()
        state.terminalDidRingBell()

        #expect(state.attentionEventCount == 3)
    }

    @Test
    func attentionCallbackFiresOncePerSignal() {
        let state = TerminalViewState()
        var firedCount = 0
        state.onAttention = { firedCount += 1 }

        state.terminalDidRingBell()
        state.terminalDidRequestDesktopNotification()

        #expect(firedCount == 2)
    }

    @Test
    func attentionCallbackIsOptional() {
        let state = TerminalViewState()

        state.terminalDidRingBell()

        #expect(state.attentionEventCount == 1)
    }
}
