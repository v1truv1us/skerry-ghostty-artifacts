# Binary dependency notice inventory

Inventory reviewed 2026-09-04 for Ghostty
`70c498ac3273661aebf6cce9904c0d42b2e5d299`, binary SHA-256
`ccbf7d5f7de55eeb5031c6bf46d0e9b09de9b11bfae532b3093d8ef09832a3cc`.
This inventories dependencies and collected texts; the distribution gate is
still open for the gaps below.

## Evidence and provenance

The local `References/ghostty-upstream` working tree is not the release pin.
Use `git show <GHOSTTY_REF>:<path>`, not its current files, for release review.
[The pinned root dependency manifest](Notices/ghostty-build.zig.zon.txt) is
retained here. `pkg/*/build.zig.zon` at that same commit pins C dependencies.
[inventory.json](Notices/inventory.json) records 15 cached source-archive
identities, their archive SHA-256 values and collected notice paths. Zig package
hashes are source-tree identities, not the SHA-256 of the compressed archive.
Archive filenames/cache presence alone are not proof of binary inclusion or
independent revalidation of the original Zig package hash.

Build configuration: embedded runtime, Sentry/custom shaders/inspector/i18n
disabled. The Darwin font default is CoreText. Inspection of the iOS archive
shows FreeType, PNG, zlib, Oniguruma and Highway objects. Source build-graph
imports also identify Zig modules, embedded fonts and compiled C utilities.
The inventory conservatively includes their notices even when final application
dead stripping may discard some code.

## Collected dependency texts

| Component | Evidence / notice location |
| --- | --- |
| Ghostty and Swift wrapper | [GHOSTTY-LICENSE](GHOSTTY-LICENSE), [LICENSE](LICENSE); distinct copyright holders |
| FreeType | [Notices/freetype](Notices/freetype): upstream license overview and FreeType License; archive contains `ftbase.o`, `autofit.o` and other font modules |
| PNG / zlib / Oniguruma / Highway | Corresponding directories under `Notices/`; archive member evidence and pinned `pkg/` build dependencies |
| libxev / vaxis / zig-objc / uucode / zf | Corresponding `Notices/` directories; pinned root Zig dependencies; uucode has additional missing notices below |
| Wuffs / pixels / zigimg | Corresponding `Notices/` directories; image modules and transitive source dependency notices conservatively retained |
| JetBrains Mono / Nerd Fonts symbols | [Notices/jetbrains-mono](Notices/jetbrains-mono), [Notices/nerd-fonts](Notices/nerd-fonts); font archives are pinned in the root manifest; Nerd Fonts component coverage needs follow-up |
| Theme catalog | [Sources/GhosttyTheme/LICENSE](Sources/GhosttyTheme/LICENSE); Swift product is separate from the binary |
| MSDisplayLink | Separate SwiftPM dependency; its own resolved checkout carries its license; include it in the app's aggregate notices |

z2d's `LICENSE` and `COPYING` were retrieved from its exact pinned commit
`7dbae85c81784dba9988320bf9543ed9a81350c8` in `vancluever/z2d`.
uucode's supplemental and wcwidth-resource notices were retrieved from
`2826a37a4562284fdacd8fa029d49509cc9bffcd` in `jacobsandlund/uucode`.
Their repository paths are preserved under `Notices/z2d/` and `Notices/uucode/`;
these fill omissions in the cached archives. The wcwidth notices are retained
conservatively even where resources are only used to generate tables.

## Remaining distribution tasks

| Gap | Evidence and required action |
| --- | --- |
| z2d source delivery | The MPL-2.0 text and upstream copyright/derived-code notices are now collected. Retain exact corresponding source/distribution instructions with the release. Do not label the entire static dependency set MIT. |
| uucode notice delivery | The missing Unicode/helper texts and seven wcwidth-resource notices are now collected at the pinned revision. Include them with the aggregate distributed notices. |
| Vendored code and runtime | Audit pinned `pkg/simdutf/vendor/`, `src/stb/`, and the Zig compiler runtime (the archive contains `compiler_rt.o`). Retain their complete upstream notices and any bundled-code exceptions, rather than relying on Ghostty's MIT file. |
| Fonts and FreeType subcomponents | Nerd Fonts' top-level MIT notice does not itself establish coverage of every embedded glyph source. Verify component/font notices and FreeType's referenced subcomponent terms against the files actually compiled. |
| Delivery and release | Include the completed notice bundle with a new binary distribution and in Skerry's app acknowledgments/resources. Existing immutable assets cannot be amended. Verify all slices and final app delivery before closing `RF-04`; do not republish the existing bytes under a new version as though these gaps were fixed. |

## Excluded or conditional components

GNU libintl is disabled and checked by `Script/check-no-libintl.sh`. Ghostty's
native Sentry/Breakpad, inspector/ImGui and shader translators are disabled by
the build flags. HarfBuzz and Fontconfig are conditional on nondefault font
backends; do not infer they ship merely because they appear in `build.zig.zon`.
GTK/Wayland and JS/Wasm are outside the Apple embedded targets. Translate-C/Aro
are build tools; their presence in the cache is not evidence they ship as runtime
libraries. Revisit these classifications whenever flags, targets or pins change.

## Updating the inventory

Verify the committed notice set from the package root with
`shasum -a 256 -c NOTICES.sha256`. The checksum list covers the collected texts
and provenance snapshots, not a claim that all distribution obligations are
closed. License content is retained; trailing whitespace/newlines at EOF are
normalized to a single newline as recorded in the inventory.

Read the exact source pin and local patches; identify archive members and Zig
imports; collect upstream texts without rewriting their terms; record source
identities/checksums; verify actual delivery. Keep unresolved items explicit.
The package's [maintenance backlog](MAINTENANCE.md) tracks this as `LIB-01`.
