# Upstream Provenance

Ghostty source:

- Repository: `https://github.com/ghostty-org/ghostty`
- Pinned commit: `70c498ac3273661aebf6cce9904c0d42b2e5d299`
- Patch set: every executable `.patch` and `.sh` file in `Patches/ghostty`,
  applied in lexical order to a clean checkout by `Script/apply-patches.sh`
  (`apply-patches.sh` chooses the compatible host-managed I/O variant before
  applying the remaining ordered patch inventory; the checksum-pinned libxev
  compatibility step runs after Zig materializes that dependency)

The package wrapper originated from `https://github.com/Lakr233/libghostty-spm`.
`build/BUILD_INFO.txt` records exact patch SHA-256 hashes, Xcode/Zig/Swift
versions, and artifact checksums for the latest local rebuild.

Skerry completed and tested its own clean from-source build at this ref on
2026-07-30 using the current Xcode 26.5, Metal Toolchain, and Zig 0.16.0; see
`TOOLCHAIN_VERSIONS` and `build/BUILD_INFO.txt` for exact evidence. Its zip has
SHA-256 and SwiftPM checksum
`ccbf7d5f7de55eeb5031c6bf46d0e9b09de9b11bfae532b3093d8ef09832a3cc`.
Ghostty translations are disabled for this embedded build, and the build gate
audits every static archive to prove GNU libintl symbols are absent.

Published 2026-09-04: `Package.swift` resolves the exact checksum above from
the immutable Skerry-owned binary release:
`https://github.com/v1truv1us/skerry-ghostty-artifacts/releases/download/ghostty-70c498ac-2/GhosttyKit.xcframework.zip`.
The release also contains `BUILD_INFO.txt`. Public Swift package tag `0.2.1`
is immutable and has 119 passing host-package tests with a fresh binary
download. `Package.local.swift` targets `BinaryTarget/GhosttyKit.xcframework`
for explicit source-build development and verification.

Local iOS and package verification run through
`Scripts/with-local-ghostty-manifest.sh`, which temporarily swaps
`Package.local.swift` over `Package.swift` for the command and restores the
production manifest on exit (mirroring `Script/test-local-artifact.sh`). The
wrapper fails fast with a pointer to `build.sh` if the local XCFramework is
missing, so `bun run ios:test`, `ios:build`, `ios:test:ui:*`, `ghostty:test`,
and `verify:local` build against the patched artifact without a manual swap.

The library's terminal fixes, ownership boundaries and remaining work are in
[MAINTENANCE.md](MAINTENANCE.md). Collected dependency notices, source identities
and unresolved distribution tasks are in [NOTICES.md](NOTICES.md). Publication
and automated tests do not establish completion of those distribution tasks.
