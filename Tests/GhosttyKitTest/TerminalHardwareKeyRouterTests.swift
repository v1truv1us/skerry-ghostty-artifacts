#if canImport(AppKit)
import AppKit
#endif
import Foundation
import GhosttyKit
@testable import GhosttyTerminal
import Testing

struct TerminalHardwareKeyRouterTests {
    @Test
    func routesUIKitArrowKeysDirectlyForInMemoryBackends() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x50,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[D".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x52,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[A".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x2A,
                backend: .inMemory(session)
            ) == .data(Data([0x7F]))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x29,
                backend: .inMemory(session)
            ) == .data(Data([0x1B]))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x2B,
                backend: .inMemory(session)
            ) == .data(Data([0x09]))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x4D,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[F".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x4A,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[H".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x4B,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[5~".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x4E,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[6~".utf8))
        )
    }

    @Test
    func routesUIKitExtendedAccessoryKeysDirectlyForInMemoryBackends() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        let expectedSequences: [(usage: UInt16, sequence: String)] = [
            (0x49, "\u{1B}[2~"),
            (0x4C, "\u{1B}[3~"),
            (0x3A, "\u{1B}OP"),
            (0x3B, "\u{1B}OQ"),
            (0x3C, "\u{1B}OR"),
            (0x3D, "\u{1B}OS"),
            (0x3E, "\u{1B}[15~"),
            (0x3F, "\u{1B}[17~"),
            (0x40, "\u{1B}[18~"),
            (0x41, "\u{1B}[19~"),
            (0x42, "\u{1B}[20~"),
            (0x43, "\u{1B}[21~"),
            (0x44, "\u{1B}[23~"),
            (0x45, "\u{1B}[24~"),
        ]

        for expected in expectedSequences {
            #expect(
                TerminalHardwareKeyRouter.routeUIKit(
                    usage: expected.usage,
                    backend: .inMemory(session)
                ) == .data(Data(expected.sequence.utf8))
            )
        }
    }

    @Test
    func routesStickyShiftTabDirectlyForInMemoryBackends() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })

        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x2B,
                backend: .inMemory(session),
                modifiers: .shift
            ) == .data(Data("\u{1B}[Z".utf8))
        )
    }

    @Test
    func routesUIKitKeysToGhosttyForExecBackends() {
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x50,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_ARROW_LEFT)
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x04,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_A)
        )
    }

    @Test
    func routesModifiedUIKitArrowKeysToGhosttyForInMemoryBackends() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x50,
                backend: .inMemory(session),
                modifiers: .alt
            ) == .ghostty(GHOSTTY_KEY_ARROW_LEFT)
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x4F,
                backend: .inMemory(session),
                modifiers: .ctrl
            ) == .ghostty(GHOSTTY_KEY_ARROW_RIGHT)
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x29,
                backend: .inMemory(session),
                modifiers: .super_
            ) == .ghostty(GHOSTTY_KEY_ESCAPE)
        )
        #expect(
            TerminalHardwareKeyRouter.routeUIKit(
                usage: 0x2A,
                backend: .inMemory(session),
                modifiers: .alt
            ) == .ghostty(GHOSTTY_KEY_BACKSPACE)
        )
    }

    @Test
    func routesAppKitArrowKeysDirectlyForInMemoryBackends() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x7B,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[D".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x75,
                backend: .inMemory(session)
            ) == .data(Data("\u{1B}[3~".utf8))
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x30,
                backend: .inMemory(session)
            ) == .data(Data([0x09]))
        )
    }

    @Test
    func routesAppKitKeysToGhosttyForExecBackends() {
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x7B,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_ARROW_LEFT)
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x33,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_BACKSPACE)
        )
    }

    #if canImport(AppKit)
    @Test
    func appKitInterpretedCommandsAreReplayedAsKeyEvents() {
        #expect(
            TerminalKeyEventHandler.shouldReplayInterpretedCommand(
                #selector(NSResponder.insertTab(_:))
            )
        )
        #expect(
            TerminalKeyEventHandler.shouldReplayInterpretedCommand(
                NSSelectorFromString("insertBacktab:")
            )
        )
        #expect(
            TerminalKeyEventHandler.shouldReplayInterpretedCommand(
                #selector(NSResponder.moveUp(_:))
            )
        )
    }
    #endif

    /// Quote HID 0x34 must translate to AppKit keycode 0x27, not fall
    /// through to `0` (which is AppKit's keycode for the `A` key) nor to
    /// `GHOSTTY_KEY_QUOTE.rawValue` (which happens to equal AppKit's
    /// keycode for Tab — the original bug).
    @Test
    func appKitKeyCodeForUIKitTranslatesQuoteToMacKeycode() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x34) == 0x27
        )
    }

    @Test
    func appKitKeyCodeForUIKitTranslatesCommonKeys() {
        // Letter A: HID 0x04 → AppKit 0x00
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x04) == 0x00
        )
        // Tab: HID 0x2B → AppKit 0x30
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x2B) == 0x30
        )
        // Enter: HID 0x28 → AppKit 0x24
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x28) == 0x24
        )
        // ArrowUp: HID 0x52 → AppKit 0x7E
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x52) == 0x7E
        )
    }

    @Test
    func appKitKeyCodeForGhosttyKeysTranslatesCommonKeys() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_A) == 0x00
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_TAB) == 0x30
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_ESCAPE) == 0x35
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_ARROW_LEFT) == 0x7B
        )
    }

    @Test
    func appKitKeyCodeForGhosttyKeysTranslatesHigherFunctionAndVolumeKeys() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_F17) == 0x40
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_F18) == 0x4F
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_F19) == 0x50
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_F20) == 0x5A
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_AUDIO_VOLUME_UP) == 0x48
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_AUDIO_VOLUME_DOWN) == 0x49
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_AUDIO_VOLUME_MUTE) == 0x4A
        )
    }

    @Test
    func appKitKeyCodeForGhosttyKeysReturnsSentinelForKeysAbsentFromMac() {
        let sentinel = TerminalHardwareKeyRouter.unidentifiedAppKitKeyCode
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_CONTEXT_MENU) == sentinel
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_INSERT) == sentinel
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_CUT) == sentinel
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCode(for: GHOSTTY_KEY_INTL_BACKSLASH) == sentinel
        )
    }

    /// HID usages that have no AppKit counterpart must not collapse to `0`
    /// (AppKit's keycode for `A`). They must return the sentinel so
    /// libghostty's native-keycode lookup resolves them to `.unidentified`.
    @Test
    func appKitKeyCodeForUIKitReturnsSentinelForKeysAbsentFromMac() {
        let sentinel = TerminalHardwareKeyRouter.unidentifiedAppKitKeyCode
        // CUT, COPY, PASTE, CONTEXT_MENU, INSERT, PRINT_SCREEN, SCROLL_LOCK,
        // PAUSE and the higher function keys past F20 are in uiKitMap but
        // have no AppKit virtual keycode.
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7B) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7C) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7D) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x65) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x49) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x46) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x47) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x48) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x70) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x71) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x72) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x73) == sentinel)
    }

    @Test
    func appKitKeyCodeForUIKitTranslatesDivergentAndHigherFunctionKeys() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x53) == 0x47
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x6C) == 0x40
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x6D) == 0x4F
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x6E) == 0x50
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x6F) == 0x5A
        )
    }

    @Test
    func appKitKeyCodeForUIKitTranslatesVolumeKeys() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x7F) == 0x4A
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x80) == 0x48
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x81) == 0x49
        )
    }

    /// The pinned Ghostty keycode table resolves the international backslash
    /// HID usage (`0x64`) to AppKit's ISO section keycode (`0x0A`).
    @Test
    func appKitKeyCodeForUIKitTranslatesIntlBackslashKey() {
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x64) == 0x0A
        )
        #expect(
            TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x32)
                == TerminalHardwareKeyRouter.unidentifiedAppKitKeyCode
        )
    }

    @Test
    func routeAppKitRecognizesHigherFunctionAndVolumeKeys() {
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x40,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_F17)
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x5A,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_F20)
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x48,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_AUDIO_VOLUME_UP)
        )
        #expect(
            TerminalHardwareKeyRouter.routeAppKit(
                keyCode: 0x4A,
                backend: .exec
            ) == .ghostty(GHOSTTY_KEY_AUDIO_VOLUME_MUTE)
        )
    }

    @Test
    func appKitKeyCodeForUIKitReturnsSentinelForUnknownHID() {
        // HID usages not in uiKitMap at all.
        let sentinel = TerminalHardwareKeyRouter.unidentifiedAppKitKeyCode
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0xFFFE) == sentinel)
        #expect(TerminalHardwareKeyRouter.appKitKeyCodeForUIKit(usage: 0x0001) == sentinel)
    }

    #if canImport(AppKit)
    @Test
    func appKitDirectInputRequiresNoModifiers() {
        #expect(
            TerminalKeyEventHandler.shouldUseDirectInput(
                modifierFlags: []
            )
        )
        #expect(
            !TerminalKeyEventHandler.shouldUseDirectInput(
                modifierFlags: [.shift]
            )
        )
        #expect(
            !TerminalKeyEventHandler.shouldUseDirectInput(
                modifierFlags: [.control]
            )
        )
        #expect(
            !TerminalKeyEventHandler.shouldUseDirectInput(
                modifierFlags: [.option]
            )
        )
        #expect(
            !TerminalKeyEventHandler.shouldUseDirectInput(
                modifierFlags: [.command]
            )
        )
    }
    #endif
}
