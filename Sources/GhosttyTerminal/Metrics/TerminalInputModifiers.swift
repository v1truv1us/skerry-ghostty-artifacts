//
//  TerminalInputModifiers.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

import GhosttyKit

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

public struct TerminalInputModifiers: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let shift = TerminalInputModifiers(rawValue: 1 << 0)
    public static let ctrl = TerminalInputModifiers(rawValue: 1 << 1)
    public static let alt = TerminalInputModifiers(rawValue: 1 << 2)
    public static let super_ = TerminalInputModifiers(rawValue: 1 << 3)
    public static let caps = TerminalInputModifiers(rawValue: 1 << 4)
    public static let num = TerminalInputModifiers(rawValue: 1 << 5)
    public static let shiftRight = TerminalInputModifiers(rawValue: 1 << 6)
    public static let ctrlRight = TerminalInputModifiers(rawValue: 1 << 7)
    public static let altRight = TerminalInputModifiers(rawValue: 1 << 8)
    public static let superRight = TerminalInputModifiers(rawValue: 1 << 9)

    /// Routing for a synthesized (touch) single-tap click. A touch has no
    /// hardware modifier key, so an uncaptured tap emulates Command to reach
    /// Ghostty's local link check — a plain tap has no other use when nothing
    /// remote is reading the mouse. When the remote program has captured the
    /// mouse (tmux, vim, or a full-screen coding-agent CLI enabling mouse
    /// reporting for its own click handling), an ordinary tap is forwarded
    /// unmodified instead, matching AppKit's real-modifier `mouseDown` parity.
    /// Arming the visible Command accessory is the explicit local-only escape
    /// hatch. Ghostty requires Shift to bypass remote mouse capture and then
    /// evaluates Command for the local link action, so the captured route must
    /// carry both modifiers. A local-link route also refreshes hover state from
    /// outside the viewport first because Ghostty otherwise drops a modifier-
    /// only update at the same pointer coordinates.
    static func singleTapClickPlan(
        isMouseCaptured: Bool,
        prefersRemotePointerInput: Bool = false,
        explicitlyActivatesLink: Bool = false
    ) -> TerminalTapEventPlan {
        if isMouseCaptured || prefersRemotePointerInput {
            return explicitlyActivatesLink
                ? TerminalTapEventPlan(
                    modifiers: [.shift, .super_],
                    refreshesLinkState: true
                )
                : TerminalTapEventPlan(
                    modifiers: [],
                    refreshesLinkState: false
                )
        }
        return TerminalTapEventPlan(
            modifiers: .super_,
            refreshesLinkState: true
        )
    }

    public static func singleTapClick(
        isMouseCaptured: Bool,
        prefersRemotePointerInput: Bool = false,
        explicitlyActivatesLink: Bool = false
    ) -> TerminalInputModifiers {
        singleTapClickPlan(
            isMouseCaptured: isMouseCaptured,
            prefersRemotePointerInput: prefersRemotePointerInput,
            explicitlyActivatesLink: explicitlyActivatesLink
        ).modifiers
    }

    public var ghosttyMods: ghostty_input_mods_e {
        ghostty_input_mods_e(rawValue)
    }

    #if canImport(UIKit)
        public init(from flags: UIKeyModifierFlags) {
            var mods = TerminalInputModifiers()
            if flags.contains(.shift) { mods.insert(.shift) }
            if flags.contains(.control) { mods.insert(.ctrl) }
            if flags.contains(.alternate) { mods.insert(.alt) }
            if flags.contains(.command) { mods.insert(.super_) }
            if flags.contains(.alphaShift) { mods.insert(.caps) }
            if flags.contains(.numericPad) { mods.insert(.num) }
            self = mods
        }

    #elseif canImport(AppKit)
        public init(from flags: NSEvent.ModifierFlags) {
            var mods = TerminalInputModifiers()
            if flags.contains(.shift) { mods.insert(.shift) }
            if flags.contains(.control) { mods.insert(.ctrl) }
            if flags.contains(.option) { mods.insert(.alt) }
            if flags.contains(.command) { mods.insert(.super_) }
            if flags.contains(.capsLock) { mods.insert(.caps) }
            if flags.contains(.numericPad) { mods.insert(.num) }
            self = mods
        }
    #endif
}

struct TerminalTapEventPlan: Equatable {
    let modifiers: TerminalInputModifiers
    let refreshesLinkState: Bool
}
