# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

When this package is edited inside Skerry, also follow `../../AGENTS.md`. In
particular, document lifecycle/concurrency/privacy reasoning, add a focused
regression for user-visible failures, and update Skerry's status/runbook when
package behavior or verification evidence changes.

## Project Overview

SPM package wrapping Ghostty terminal emulator C library for Apple platforms (macOS 13+, iOS 16+, Mac Catalyst 16+). Four library products:

- **GhosttyKit** — minimal re-export of the libghostty C API (`@_exported import libghostty`)
- **GhosttyTerminal** — Swift wrapper: native views, SwiftUI integration, input handling, display link, host-managed I/O
- **GhosttyTheme** — 485 terminal color themes from iTerm2-Color-Schemes (MIT License, depends on GhosttyTerminal)
- **ShellCraftKit** — sandboxed shell emulation framework (depends on GhosttyTerminal)

Binary target: pre-built `libghostty` XCFramework. Dependency: MSDisplayLink ^2.1.0.

## Build & Test Commands

```bash
# Build the SPM package
swift build

# Run tests
swift test

# Multi-destination build verification (macOS, iOS, iOS Simulator, Mac Catalyst)
./Script/test.sh

# Build full XCFramework from Ghostty source (requires zig)
./build.sh
./build.sh --platforms macos,ios --source /path/to/ghostty --skip-tests

# Generate Package.swift for release
./Script/build-manifest.sh

# Regenerate GhosttyTheme Swift files from iTerm2-Color-Schemes
./Script/generate-themes.sh
```

## Architecture

```
GhosttyKit (C API re-export)
  └─ libghostty.a (Zig → static lib) + ghostty.h

GhosttyTerminal (Swift wrapper, ~40 files)
  ├─ Configuration/    Config structs, themes, color schemes, ghostty.conf rendering
  ├─ Controller/       TerminalController — app lifecycle, config, surface creation
  ├─ InMemory/         Sandbox-safe I/O backend (no PTY), C callback bridge
  ├─ Metrics/          Grid size, viewport dimensions, input/scroll modifiers
  ├─ Platform/AppKit/  macOS NSView: input, IME, key events
  ├─ Platform/UIKit/   iOS UIView: UITextInput, keyboard, touch/gesture, IME, input accessory bar
  ├─ State/            @Observable TerminalViewState (SwiftUI state container)
  ├─ Surface/          Metal rendering bridge, display link, surface lifecycle
  └─ View/             SwiftUI TerminalSurfaceView + platform representables

GhosttyTheme (485 terminal color themes)
  ├─ GhosttyThemeDefinition     — theme data model (name, colors, palette)
  ├─ GhosttyThemeCatalog        — static catalog, search, lookup by name
  ├─ +TerminalConfiguration     — bridge to TerminalConfiguration/TerminalTheme, isDark helper
  └─ Themes/                    — auto-generated Swift files (A-Z) from iTerm2-Color-Schemes

ShellCraftKit (~5 files)
  ├─ Definition/       ShellDefinition, SandboxShell, ShellCommand protocol
  └─ Session/          ShellSession + Bridge + Engine
```

Key types: `TerminalViewState` (@Observable, SwiftUI entry point), `TerminalSurfaceView` (SwiftUI view), `TerminalView` (platform typealias: UITerminalView / AppTerminalView), `TerminalController`, `InMemoryTerminalSession`, `GhosttyThemeDefinition`, `GhosttyThemeCatalog`.

### Platform Branching

Use `#if canImport(UIKit)` FIRST, then `#else #if canImport(AppKit)` — Catalyst imports both UIKit and AppKit.

### Host-Managed I/O

All example apps run in App Sandbox. Use `GHOSTTY_SURFACE_IO_BACKEND_HOST_MANAGED` for non-PTY I/O. Never disable sandbox or spawn subprocesses.

### iOS Input Architecture (UITextInput)

`UITerminalView` conforms to `UITextInput` (which includes `UIKeyInput`) to receive both software keyboard and hardware keyboard input on iOS/Catalyst. The input chain:

1. **Hardware keys** → `pressesBegan`/`pressesEnded` in `+Keyboard.swift` → builds `ghostty_input_key_s` → `surface.sendKeyEvent()`. Sets `hardwareKeyHandled = true` to suppress the duplicate `insertText`/`deleteBackward` that UIKit would otherwise deliver.
2. **Software keyboard** → UIKit calls `insertText(_:)` / `deleteBackward()` via UIKeyInput. Guarded by `hardwareKeyHandled` flag to avoid double-processing hardware key presses.
3. **Input accessory bar** (iOS only, excludes Catalyst) → `TerminalInputAccessoryView` provides a compact two-row toolbar above the software keyboard. Controls are 44 points wide and 32 points high with low-radius rounded-rectangle chrome; arrow keys use filled arrowheads so Up remains visually distinct from the outlined Control symbol. The row nearest the keyboard holds the navigation cluster (Home, Page Up, arrows, Page Down, End, in that bracketed order) followed by the host app's custom actions; the row farthest from the keyboard normally holds Interrupt, Escape, More Keys, modifier keys (Ctrl/Alt/Cmd), Tab, symbol keys, and Paste. More Keys swaps only that far row to Shift, Insert, Forward Delete, and F1–F12, preserving the bar's 80-point height. This split and ordering exist so the most-reached-for keys need the least scrolling — reordering it back to a single row or moving navigation off the near row reintroduces that reachability problem. Modifier keys support **sticky states**: tap to arm (consumed after next input), double-tap to lock (persists until toggled off). Shift remains armed while switching More Keys modes so Shift+Tab can send Backtab. Armed/locked Command followed by a terminal tap is the explicit local-only link action inside a mouse-capturing TUI; ordinary captured taps remain plain remote clicks. Sticky modifier state is tracked by `TerminalStickyModifierState`. Actions are dispatched via `UITerminalView+InputAccessory.swift`. Button colors are configurable via `TerminalInputAccessoryStyle` (regular/active background and foreground), exposed as `UITerminalView.inputAccessoryStyle`.
4. **IME / marked text** → `setMarkedText` / `unmarkText` delegate to `TerminalTextInputHandler`, which calls `surface.preedit()` for inline composition preview. Committed text goes through `insertText`. Sticky modifiers are respected during IME composition.
5. **Text positioning** → `TerminalTextPosition` / `TerminalTextRange` (UITextPosition/UITextRange subclasses) provide minimal cursor geometry. `caretRect`/`firstRect` use `surface.imePoint()` for IME candidate window placement.

Files in `Platform/UIKit/`:

- `UITerminalView.swift` — main view, `canBecomeFirstResponder`, coordinator setup
- `UITerminalView+UITextInput.swift` — full UITextInput conformance (UIKeyInput, marked text, positions, geometry)
- `UITerminalView+Keyboard.swift` — hardware key handling via UIPress, modifier translation
- `UITerminalView+InputAccessory.swift` — input accessory bar integration, key actions, sticky modifier dispatch
- `UITerminalView+Interaction.swift` — touch scrolling, momentum scroll via CADisplayLink, Catalyst pointer/mouse
- `UITerminalView+Lifecycle.swift` — display scale, sublayer frames, focus, color scheme
- `TerminalInputAccessoryView.swift` — input accessory bar UIView (blur background, two independently-scrollable button rows)
- `TerminalAccessoryButton.swift` — the accessory bar's individual button control (regular/modifier styling, sticky lock indicator)
- `TerminalInputAccessoryStyle.swift` — configurable button colors for the accessory bar (regular/active background and foreground)
- `TerminalInputBarKey.swift` — enum defining accessory bar key types (esc, tab, arrows, home, page up/down, end, insert, forward delete, F1–F12, symbols, paste)
- `TerminalStickyModifierState.swift` — modifier key state machine (inactive/armed/locked, double-tap locking)
- `TerminalTextInputHandler@UIKit.swift` — IME state machine (marked text, preedit bridge, sticky modifier support)
- `TerminalTextPosition.swift` — TerminalTextPosition / TerminalTextRange subclasses

The macOS equivalent uses `NSTextInputClient` in `AppTerminalView+NSTextInputClient.swift` with a parallel `TerminalTextInputHandler@AppKit.swift`.

### Manifest Sync

When changing SwiftPM products, targets, or test dependencies, update all three together:

- `Package.swift` — production manifest (remote XCFramework URL + checksum)
- `Package.local.swift` — local development (path-based binary target)
- `Package.swift.template` — CI template with `__DOWNLOAD_URL__` / `__CHECKSUM__` placeholders

## Swift Code Style

- **4-space indentation**, opening brace on same line
- PascalCase types, camelCase properties/methods
- PascalCase files for types, `+` for extensions (e.g., `AppTerminalView+Input.swift`)
- **@Observable macro** over ObservableObject/@Published
- **Swift concurrency**: async/await, Task, actor, @MainActor
- Early returns, guard statements, single responsibility per type/extension
- Value types over reference types, composition over inheritance
- Dependency injection over singletons
- Avoid protocol-oriented design unless necessary
- Split files frequently — keep files small and focused (~40-100 lines typical)
- Don't extract methods unnecessarily — avoid premature abstraction

## Shell Script Style

- Shebang: `#!/bin/zsh`, failure handling: `set -euo pipefail`
- Output: `[+]` success, `[-]` failure, lowercase messages
- Minimal comments, no color output, assume tools available
- Don't add if-checks when pipefail handles failures

## GhosttyKit Design Requirements

### Wrapper Design

- GhosttyTerminal must expose **all** functionality from `ghostty.h`
- Clean Swift APIs mapping to C API: config, app lifecycle, surfaces, input, clipboard, inspector, splits, mouse, IME, text selection
- Proper Swift patterns: enums for C enums, structs for C structs, closures for callbacks

### Example App Requirements

- Apps run in **App Sandbox** — must NOT spawn subprocesses (non-negotiable)
- Use mock terminal IO with real GhosttyTerminal surface/view layer
- Use host-managed I/O backend, never disable sandbox for PTY workarounds
- Keep echo terminal as self-contained module separate from GhosttyKit integration
