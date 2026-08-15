enum TerminalTouchScrollOwner {
    case undecided
    case terminal
    case localScrollback
    case hostScrollback
    /// The host could not prove current screen context. Ignore this gesture;
    /// sending Ghostty wheel fallback into an ambiguous TUI can type Up/Down.
    case unavailable
}

/// A content-free decision supplied by the host for one touch-scroll gesture.
/// Mouse-capturing applications still bypass this and receive wheel input.
public enum TerminalTouchScrollDestination: Equatable, Sendable {
    case terminal
    case localScrollback
    case hostScrollback
}

enum TerminalTouchScrollRouting {
    static func initialOwner(
        isMouseCaptured: Bool,
        prefersRemotePointerInput: Bool = false,
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
        guard !prefersRemotePointerInput,
              hasHostHandler,
              isUncapturedAlternateScreen,
              !isMouseCaptured
        else { return .terminal }
        return .hostScrollback
    }
}
