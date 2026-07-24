# Upstream Provenance

Ghostty source:

- Repository: `https://github.com/ghostty-org/ghostty`
- Pinned commit: `35e1a0160c4f6797e1bb1ef8e7a2b8c6b114ab58`
- Patch set: every executable `.patch` and `.sh` file in `Patches/ghostty`,
  applied in lexical order to a clean checkout by `Script/apply-patches.sh`
  (the two `0002-host-managed-io*` variants are mutually exclusive, selected
  by detecting which host-managed I/O API shape the pinned commit exposes)

The package wrapper originated from `https://github.com/Lakr233/libghostty-spm`.
`build/BUILD_INFO.txt` records exact patch SHA-256 hashes, Xcode/Zig/Swift
versions, and artifact checksums for the latest local rebuild.

Skerry has not yet completed its own from-source rebuild at this ref (see
`TOOLCHAIN_VERSIONS` for the blocker), so `Package.swift` (the production
manifest) points its `libghostty` binary target directly at upstream's own
published, checksummed release built from this same pinned commit:
`https://github.com/Lakr233/libghostty-spm/releases/download/storage.1.3.1/GhosttyKit.xcframework.zip`
(sha256 `cfb3fbbfe1365e4c90e01969e2576b4dfa33f04975bcafd84c6368514f791fe9`,
checksum matched against upstream's own `Package.swift` and verified by
SwiftPM on fetch). `Package.local.swift` keeps the path-based binary target
against a local extraction of that same zip in `BinaryTarget/`, for local
iteration without a network fetch.

The XCFramework is not published by Skerry itself yet. Before redistribution,
review Ghostty and all statically linked dependency licenses and notices;
this provenance record is not a substitute for a legal licensing review.
