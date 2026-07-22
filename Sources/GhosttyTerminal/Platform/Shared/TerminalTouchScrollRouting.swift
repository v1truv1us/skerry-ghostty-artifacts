enum TerminalTouchScrollOwner {
    case undecided
    case terminal
    case host
}

enum TerminalTouchScrollRouting {
    static func initialOwner(
        isMouseCaptured: Bool,
        hasHostHandler: Bool,
        isUncapturedAlternateScreen: Bool
    ) -> TerminalTouchScrollOwner {
        // Captured applications such as OpenCode must receive wheel events,
        // and a primary-screen shell must retain Ghostty's local scrollback.
        // An uncaptured alternate screen is different: Ghostty's DECSET 1007
        // behavior converts a wheel into Up/Down keys, which cycles Codex's
        // prompt history instead of revealing prior output. Only a host that
        // has independently proven that exact screen state may use its own
        // scrollback implementation (for Skerry, confirmed tmux copy mode).
        guard hasHostHandler,
              isUncapturedAlternateScreen,
              !isMouseCaptured
        else { return .terminal }
        return .host
    }
}
