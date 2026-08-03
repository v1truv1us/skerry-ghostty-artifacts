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

Until that exact zip is published at a Skerry-owned immutable URL,
`Package.swift` (the production manifest) continues to point its `libghostty`
binary target at the prior upstream published release:
`https://github.com/Lakr233/libghostty-spm/releases/download/storage.1.3.1/GhosttyKit.xcframework.zip`
(sha256 `cfb3fbbfe1365e4c90e01969e2576b4dfa33f04975bcafd84c6368514f791fe9`,
checksum matched against upstream's own `Package.swift` and verified by
SwiftPM on fetch). `Package.local.swift` targets the newly built local
`BinaryTarget/GhosttyKit.xcframework` for development and verification.

Local iOS and package verification run through
`Scripts/with-local-ghostty-manifest.sh`, which temporarily swaps
`Package.local.swift` over `Package.swift` for the command and restores the
production manifest on exit (mirroring `Script/test-local-artifact.sh`). The
wrapper fails fast with a pointer to `build.sh` if the local XCFramework is
missing, so `bun run ios:test`, `ios:build`, `ios:test:ui:*`, `ghostty:test`,
and `verify:local` build against the patched artifact without a manual swap.

The newly built XCFramework is not published by Skerry itself yet. Before
redistribution, review Ghostty and all statically linked dependency licenses
and notices; this provenance record is not a substitute for a legal licensing
review.
