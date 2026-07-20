# Upstream Provenance

Ghostty source:

- Repository: `https://github.com/ghostty-org/ghostty`
- Pinned commit: `063ac3ecc5adae6360ae2044dc54e7a68c64f3a1`
- Patch set: every executable `.patch` and `.sh` file in `Patches/ghostty`,
  applied in lexical order to a clean checkout by `Script/apply-patches.sh`

The package wrapper originated from `https://github.com/Lakr233/libghostty-spm`.
`build/BUILD_INFO.txt` records exact patch SHA-256 hashes, Xcode/Zig/Swift
versions, and artifact checksums for the latest local rebuild.

The XCFramework is not published yet, so `Package.swift` intentionally keeps a
local path-based binary target. Before redistribution, review Ghostty and all
statically linked dependency licenses and notices; this provenance record is
not a substitute for a legal licensing review.
