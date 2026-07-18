@testable import GhosttyTerminal
import Testing

@MainActor
struct TerminalSearchStateTests {
    @Test
    func searchStateStartsInactiveWithNoMatches() {
        let state = TerminalViewState()
        #expect(!state.isSearchActive)
        #expect(state.searchMatchCount == 0)
        #expect(state.searchSelectedIndex == 0)
    }

    @Test
    func startingSearchActivatesState() {
        let state = TerminalViewState()

        state.terminalDidStartSearch()

        #expect(state.isSearchActive)
    }

    @Test
    func matchCountAndSelectedIndexUpdateIndependently() {
        let state = TerminalViewState()
        state.terminalDidStartSearch()

        state.terminalDidUpdateSearchMatchCount(12)
        state.terminalDidUpdateSearchSelectedIndex(3)

        #expect(state.searchMatchCount == 12)
        #expect(state.searchSelectedIndex == 3)
    }

    /// Ending a search must reset match state, not just the active flag —
    /// otherwise a stale "3 of 12" would flash before the next search starts.
    @Test
    func endingSearchResetsActiveFlagAndMatchState() {
        let state = TerminalViewState()
        state.terminalDidStartSearch()
        state.terminalDidUpdateSearchMatchCount(12)
        state.terminalDidUpdateSearchSelectedIndex(3)

        state.terminalDidEndSearch()

        #expect(!state.isSearchActive)
        #expect(state.searchMatchCount == 0)
        #expect(state.searchSelectedIndex == 0)
    }
}

@MainActor
struct TerminalScrollbarStateTests {
    @Test
    func scrollbarPositionStartsNil() {
        let state = TerminalViewState()
        #expect(state.scrollbarPosition == nil)
    }

    @Test
    func scrollbarUpdateStoresLineCountsOnly() {
        let state = TerminalViewState()

        state.terminalDidUpdateScrollbar(total: 500, offset: 400, length: 100)

        #expect(state.scrollbarPosition == TerminalScrollbarPosition(total: 500, offset: 400, length: 100))
    }

    @Test
    func isAtBottomWhenViewportReachesTotal() {
        let position = TerminalScrollbarPosition(total: 500, offset: 400, length: 100)
        #expect(position.isAtBottom)
    }

    @Test
    func isNotAtBottomWhenScrolledUp() {
        let position = TerminalScrollbarPosition(total: 500, offset: 100, length: 100)
        #expect(!position.isAtBottom)
    }
}
