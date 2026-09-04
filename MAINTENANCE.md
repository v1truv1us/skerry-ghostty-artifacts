# Terminal maintenance and open work

Reviewed 2026-09-04. This document travels with the public package subtree.
Skerry's `docs/roadmap.md` remains the canonical app release backlog; this is
the package ownership map and its portable maintenance record.

## Where a fix belongs

| Symptom | Owner and starting point | Evidence required |
| --- | --- | --- |
| Incorrect cells, selection geometry, Metal rendering, parser or C API behavior | Ghostty core: numbered `Patches/ghostty/` patch, pinned by `GHOSTTY_REF` | Reproducer against the exact binary; clean source rebuild and all affected slices |
| Duplicate input, sticky modifiers, IME, selection handles, touch/mouse conversion or view sizing | Swift wrapper: `Sources/GhosttyTerminal/Platform/UIKit/`, `Surface/`, `InMemory/` | Named regression in `Tests/GhosttyKitTest/`; iPhone/iPad interaction evidence where required |
| Wrong tmux/herdr target, reconnect, SSH/Mosh transport, host trust, app navigation or stale app layout | Skerry host integration | App regression and exact device/build evidence; only change the package when its contract is insufficient |
| Missing slice, stale artifact, source pin or toolchain incompatibility | `Script/`, `TOOLCHAIN_VERSIONS`, `UPSTREAM.md` | Pinned clean-source provenance, immutable release and fresh remote binary resolution |

Keep terminal output as bytes. Do not inspect or log PTY content to choose a
gesture route, infer agent state, or invent selection geometry. Each pane keeps
one surface across hiding, resizing and foreground recovery.

## Implemented fixes to preserve

| Area | Implementation | Regression/acceptance anchor |
| --- | --- | --- |
| Selection endpoints | `0011-selection-range.patch` exposes geometry only; `UITerminalView+SelectionHandles.swift` renders and tracks endpoints | Package selection implementation plus Skerry `RF-09`; physical drag/cross/scroll/font/rotation checks still required |
| Resize repaint | `TerminalSurfaceCoordinator` schedules a frame when layout changes, retaining the surface | `TerminalSurfaceCoordinatorResizeTests.swift`; no black frame until later output |
| Captured TUI links and pointer input | Ordinary captured taps forward plain clicks; armed Command requests local link activation; host restricts URL schemes | `TerminalInputModifiersTests.swift`, including `testCommandArmedTapOpensLinkInsideMouseCapturedOpenCodeTerminal` |
| herdr long press and selection | Stationary hold remains remote right-click; hold-drag switches to local selection | `testHerdrHoldDragChangesFromRightClickToTextSelection`; Skerry `RF-11` still needs physical acceptance |
| Keyboard and scroll ownership | Raw Tab, modifier routing and host-owned scroll decisions live in focused routing types | `TerminalHardwareKeyRouterTests.swift`, `TerminalTouchScrollRoutingTests.swift`; Skerry `RF-10` for cross-agent device checks |

These entries are implemented behavior, not newly discovered unfixed defects.
The 119 host package tests passed for `0.2.1`; that run does not exercise UIKit
interaction on physical devices. Earlier app/device reports cannot be promoted
to acceptance of a new release candidate.

## Prioritized remaining work

| ID | State | Next work and completion condition |
| --- | --- | --- |
| LIB-01 | Open distribution gate | Finish the concrete notice gaps in [NOTICES.md](NOTICES.md), then package notices with the distributed binary/app. Repository files alone do not prove delivery to app users. |
| LIB-02 | Pending device evidence | On both iPhone and iPad verify selection endpoints, crossing, Copy, scroll, rotation and font changes against one candidate. Record device, OS, app build, package commit and artifact checksum. Fix a reproduced failure in the owner shown above. |
| LIB-03 | Pending integration evidence | Verify Codex/OpenCode scrolling, explicit tmux history, and herdr stationary hold versus hold-drag. Retain server-confirmed context and remote mouse ownership. Claude's earlier pass is not a blanket pass for other clients. |
| LIB-04 | Build simplification candidate | FreeType object files are present in the iOS archive despite CoreText defaults and disabled inspector. Investigate whether it and its PNG/zlib dependencies can be omitted. Do not remove them until all consumers and font/image tests prove they are unnecessary. |
| LIB-05 | Release automation follow-up | Validate a fresh consumer manifest, all Apple destinations, notice delivery and patch provenance before a new immutable version. Keep binary release versions distinct from Swift wrapper versions. |

No new parser/rendering defect was reproduced in this documentation review.
An unchecked interaction is a verification task until a reproducible failure
establishes the defect and owner. Do not replace this table with speculative
terminal rewrites before release.

## Carrying core patches

`0001` adds Darwin static-library installation; the compatible `0002` variant
adds host-managed I/O. `0004`/`0005` implement iOS platform/Metal integration;
`0006`/`0007` disable custom shaders/inspector. `0008` fixes macOS texture storage;
`0009` handles libc++ Apple availability. `0010` preserves fractional scrolling;
`0011` adds selected-range geometry. `0012`/`0013` bridge Zig 0.16 Catalyst tags
in Ghostty/libxev; `0014` omits libintl when translations are disabled.
See [patch rules](Patches/ghostty/README.md) before changing them.

For an upstream bump, check each patch against upstream first, remove only
superseded patches, and retain the regression that explains why it existed.
Record patch hashes in `BUILD_INFO.txt`. A core patch requires a new binary;
a Swift-only fix requires a new package tag but can reuse an unchanged binary.

## Recording a terminal issue

Record the package version, binary checksum, platform/OS, host multiplexer and
version, mouse-capture state, exact gesture/key sequence, expected result,
actual result and frequency. Use synthetic terminal content in shared examples.
Name the owning file, regression test, implementation state, automated result
and separate physical acceptance. Do not include credentials, host identifiers
or captured private terminal output. Update this document and Skerry's three
canonical release documents when status changes.
