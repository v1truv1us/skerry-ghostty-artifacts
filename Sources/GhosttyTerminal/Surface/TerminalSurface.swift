//
//  TerminalSurface.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

import Foundation
import GhosttyKit

struct TerminalSelectionRange: Equatable {
    let leading: CGPoint?
    let trailing: CGPoint?
}

/// Thread-safe wrapper around `ghostty_surface_t`.
///
/// All access must happen on the main actor. The surface should be freed
/// explicitly via ``free()`` before the wrapper is deallocated; `deinit`
/// includes a safety net but relying on it is discouraged.
@MainActor
public final class TerminalSurface {
    private var surface: ghostty_surface_t?
    private var hasBeenFreed = false

    init(_ surface: ghostty_surface_t) {
        self.surface = surface
    }

    var rawValue: ghostty_surface_t? {
        surface
    }

    // MARK: - Input

    @discardableResult
    func sendKeyEvent(_ event: ghostty_input_key_s) -> Bool {
        guard let s = surface else {
            TerminalDebugLog.log(.input, "surface key ignored: missing surface")
            return false
        }
        return ghostty_surface_key(s, event)
    }

    func sendText(_ text: String) {
        guard let s = surface else {
            TerminalDebugLog.log(.input, "surface text ignored: missing surface")
            return
        }
        text.withCString { cStr in
            ghostty_surface_text(s, cStr, UInt(text.utf8.count))
        }
    }

    @discardableResult
    func sendMouseButton(
        state: ghostty_input_mouse_state_e,
        button: ghostty_input_mouse_button_e,
        mods: ghostty_input_mods_e
    ) -> Bool {
        guard let s = surface else {
            TerminalDebugLog.log(.input, "surface mouse button ignored: missing surface")
            return false
        }
        return ghostty_surface_mouse_button(s, state, button, mods)
    }

    func sendMousePos(x: Double, y: Double, mods: ghostty_input_mods_e) {
        guard let s = surface else {
            TerminalDebugLog.log(.input, "surface mouse position ignored: missing surface")
            return
        }
        ghostty_surface_mouse_pos(s, x, y, mods)
    }

    func sendMouseScroll(x: Double, y: Double, mods: ghostty_input_scroll_mods_t) {
        guard let s = surface else {
            TerminalDebugLog.log(.input, "surface scroll ignored: missing surface")
            return
        }
        ghostty_surface_mouse_scroll(s, x, y, mods)
    }

    func preedit(_ text: String) {
        guard let s = surface else {
            TerminalDebugLog.log(.ime, "surface preedit ignored: missing surface")
            return
        }
        text.withCString { cStr in
            ghostty_surface_preedit(s, cStr, UInt(text.utf8.count))
        }
    }

    /// Captures only cursor/grid geometry. This intentionally derives the cell
    /// from Ghostty's IME point instead of adding a second terminal parser or
    /// exposing screen content to the host application.
    func predictionAnchor() -> TerminalPredictionAnchor? {
        guard let metrics = size() else { return nil }
        return TerminalPredictionGeometry.anchor(metrics: metrics, imePoint: imePoint())
    }

    /// Compares rendered cells with local UTF-8 input bytes and returns only a
    /// boolean. Terminal text never crosses this wrapper boundary, is never
    /// decoded into a String, and is freed before returning. Mosh uses this to
    /// verify an EchoAck prediction without inspecting raw PTY output.
    func contentHasPrefix(_ expected: Data, from anchor: TerminalPredictionAnchor) -> Bool {
        guard !expected.isEmpty,
              let s = surface,
              let metrics = size(),
              metrics.columns == anchor.columns,
              metrics.rows == anchor.rows,
              anchor.column < UInt32(metrics.columns),
              anchor.row < UInt32(metrics.rows)
        else { return false }

        let topLeft = ghostty_point_s(
            tag: GHOSTTY_POINT_VIEWPORT,
            coord: GHOSTTY_POINT_COORD_EXACT,
            x: anchor.column,
            y: anchor.row
        )
        let bottomRight = ghostty_point_s(
            tag: GHOSTTY_POINT_VIEWPORT,
            coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT,
            x: 0,
            y: 0
        )
        let selection = ghostty_selection_s(
            top_left: topLeft,
            bottom_right: bottomRight,
            rectangle: false
        )
        var text = ghostty_text_s(
            tl_px_x: 0,
            tl_px_y: 0,
            offset_start: 0,
            offset_len: 0,
            text: nil,
            text_len: 0
        )
        guard ghostty_surface_read_text(s, selection, &text) else { return false }
        defer { ghostty_surface_free_text(s, &text) }
        guard let bytes = text.text, text.text_len >= expected.count else { return false }

        let rendered = UnsafeRawBufferPointer(start: bytes, count: Int(text.text_len))
        return expected.enumerated().allSatisfy { index, byte in
            rendered[index] == byte
        }
    }

    // MARK: - Actions

    @discardableResult
    func performBindingAction(_ action: String) -> Bool {
        guard let s = surface else {
            TerminalDebugLog.log(.actions, "binding action ignored: missing surface")
            return false
        }
        return action.withCString { cStr in
            ghostty_surface_binding_action(s, cStr, UInt(action.utf8.count))
        }
    }

    // MARK: - Rendering

    func draw() {
        guard let s = surface else { return }
        TerminalDebugLog.log(.render, "surface draw")
        ghostty_surface_draw(s)
    }

    func refresh() {
        guard let s = surface else { return }
        TerminalDebugLog.log(.render, "surface refresh")
        ghostty_surface_refresh(s)
    }

    func setSize(width: UInt32, height: UInt32) {
        guard let s = surface else {
            TerminalDebugLog.log(.metrics, "surface setSize ignored: missing surface")
            return
        }
        TerminalDebugLog.log(.metrics, "surface setSize \(width)x\(height)")
        ghostty_surface_set_size(s, width, height)
    }

    func setContentScale(x: Double, y: Double) {
        guard let s = surface else {
            TerminalDebugLog.log(.metrics, "surface contentScale ignored: missing surface")
            return
        }
        TerminalDebugLog.log(
            .metrics,
            "surface contentScale x=\(String(format: "%.2f", x)) y=\(String(format: "%.2f", y))"
        )
        ghostty_surface_set_content_scale(s, x, y)
    }

    // MARK: - State

    func setFocus(_ focused: Bool) {
        guard let s = surface else { return }
        TerminalDebugLog.log(.lifecycle, "surface focus=\(focused)")
        ghostty_surface_set_focus(s, focused)
    }

    func setColorScheme(_ scheme: ghostty_color_scheme_e) {
        guard let s = surface else { return }
        TerminalDebugLog.log(.lifecycle, "surface colorScheme=\(scheme.rawValue)")
        ghostty_surface_set_color_scheme(s, scheme)
    }

    func setOcclusion(_ visible: Bool) {
        guard let s = surface else { return }
        TerminalDebugLog.log(.lifecycle, "surface occlusion visible=\(visible)")
        ghostty_surface_set_occlusion(s, visible)
    }

    // MARK: - Size Query

    func size() -> TerminalGridMetrics? {
        guard let s = surface else {
            TerminalDebugLog.log(.metrics, "surface size query ignored: missing surface")
            return nil
        }
        let metrics = TerminalGridMetrics(ghostty_surface_size(s))
        TerminalDebugLog.log(.metrics, "surface size \(metrics.debugSummary)")
        return metrics
    }

    // MARK: - IME

    func imePoint() -> (x: Double, y: Double, width: Double, height: Double) {
        var x: Double = 0
        var y: Double = 0
        var w: Double = 0
        var h: Double = 0
        if let s = surface {
            ghostty_surface_ime_point(s, &x, &y, &w, &h)
        }
        return (x, y, w, h)
    }

    // MARK: - Mouse Capture

    var isMouseCaptured: Bool {
        guard let s = surface else { return false }
        return ghostty_surface_mouse_captured(s)
    }

    /// Reads geometry only. Ghostty owns the conversion from its selected
    /// cells to UIKit-compatible surface points so padding, scale, viewport,
    /// and selection movement are captured atomically without exposing text.
    func selectionRange() -> TerminalSelectionRange? {
        guard let s = surface else { return nil }
        var range = ghostty_selection_range_s(
            leading_x: 0,
            leading_y: 0,
            trailing_x: 0,
            trailing_y: 0,
            leading_visible: false,
            trailing_visible: false
        )
        guard ghostty_surface_selection_range(s, &range) else { return nil }
        return TerminalSelectionRange(
            leading: range.leading_visible
                ? CGPoint(x: range.leading_x, y: range.leading_y)
                : nil,
            trailing: range.trailing_visible
                ? CGPoint(x: range.trailing_x, y: range.trailing_y)
                : nil
        )
    }

    // MARK: - Lifecycle

    func free() {
        guard !hasBeenFreed, let s = surface else { return }
        TerminalDebugLog.log(.lifecycle, "surface free")
        hasBeenFreed = true
        surface = nil
        ghostty_surface_free(s)
    }

    deinit {
        // Surface should be freed explicitly via free() before deinit.
        // The deinit safety net is intentionally removed because
        // Swift 6 strict concurrency prevents accessing @MainActor
        // state from nonisolated deinit.
    }
}
