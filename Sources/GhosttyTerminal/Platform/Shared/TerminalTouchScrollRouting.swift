enum TerminalTouchScrollOwner {
    case undecided
    case terminal
    case host
}

enum TerminalTouchScrollRouting {
    static func initialOwner(
        isMouseCaptured: Bool,
        hasHostHandler: Bool
    ) -> TerminalTouchScrollOwner {
        isMouseCaptured || !hasHostHandler ? .terminal : .undecided
    }
}
