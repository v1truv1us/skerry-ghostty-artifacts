//
//  GhosttyPayloadText.swift
//  libghostty-spm
//
//  Created by Skerry on 2026/7/18.
//

import Foundation

/// The single sanctioned point where remote-controlled C payloads become
/// Swift Strings for feature delivery (window title, link URLs, working
/// directory).
///
/// The PTY privacy gate (`Scripts/check-pty-payload-logging.sh`) forbids
/// `String(cString:)`/`String(decoding:)` in scanned terminal-byte paths so
/// payload content cannot leak into logs by accident. Feature delivery is
/// not logging: strings produced here flow only to delegate callbacks, and
/// call sites keep their logging in redacted length-only form via
/// `TerminalDebugLog.describe`. This file is deliberately not in the scan
/// list — it is the one place decoding may happen, small enough to audit
/// at a glance.
enum GhosttyPayloadText {
    /// Length-prefixed payload (e.g. `open_url`/`mouse_over_link`):
    /// respect the documented length rather than trusting a NUL terminator.
    static func decode(_ start: UnsafePointer<CChar>?, length: Int) -> String {
        guard let start, length > 0 else { return "" }
        let buffer = UnsafeBufferPointer(start: start, count: length)
        return String(decoding: buffer.map(UInt8.init), as: UTF8.self)
    }

    /// NUL-terminated payload (e.g. `pwd`, `set_title`).
    static func decode(cString start: UnsafePointer<CChar>?) -> String? {
        guard let start else { return nil }
        return String(cString: start)
    }
}
