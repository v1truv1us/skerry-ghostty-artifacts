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

    /// Modifiers for a synthesized (touch) click that should activate a
    /// recognized link. Ghostty checks for a link under Command-click, but
    /// when the remote program has captured the mouse (tmux, vim, or a
    /// full-screen coding-agent CLI enabling mouse reporting for its own
    /// scroll/click handling), a plain click is forwarded to that program
    /// instead of being checked against the link table. Shift is the same
    /// local-override signal already used to keep touch text selection
    /// working under mouse capture, so it is added here too to reach the
    /// same local, Ghostty-owned handling a link click needs.
    public static func linkActivation(isMouseCaptured: Bool) -> TerminalInputModifiers {
        isMouseCaptured ? [.super_, .shift] : .super_
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
