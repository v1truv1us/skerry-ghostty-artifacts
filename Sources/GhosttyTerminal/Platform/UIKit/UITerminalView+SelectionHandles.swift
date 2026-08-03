//
//  UITerminalView+SelectionHandles.swift
//  libghostty-spm
//

#if canImport(UIKit)
    import GhosttyKit
    import UIKit

    extension UITerminalView {
        func setupSelectionHandles() {
            startSelectionHandle.onPan = { [weak self] gesture in
                self?.handleSelectionHandlePan(gesture, edge: .start)
            }
            endSelectionHandle.onPan = { [weak self] gesture in
                self?.handleSelectionHandlePan(gesture, edge: .end)
            }
            startSelectionHandle.onAccessibilityAdjust = { [weak self] increment in
                self?.adjustSelectionEndpoint(edge: .start, increment: increment)
            }
            endSelectionHandle.onAccessibilityAdjust = { [weak self] increment in
                self?.adjustSelectionEndpoint(edge: .end, increment: increment)
            }
        }

        @discardableResult
        func synchronizeSelectionHandlesWithSurface() -> Bool {
            guard ownsTerminalSelectionRange else { return false }
            guard let range = surface?.selectionRange() else {
                hideSelectionHandles()
                return false
            }

            selectionStartPoint = range.leading
            selectionEndPoint = range.trailing
            synchronizeSelectionHandle(startSelectionHandle, with: range.leading)
            synchronizeSelectionHandle(endSelectionHandle, with: range.trailing)
            return range.leading != nil || range.trailing != nil
        }

        func hideSelectionHandles() {
            ownsTerminalSelectionRange = false
            startSelectionHandle.removeFromSuperview()
            endSelectionHandle.removeFromSuperview()
            selectionStartPoint = nil
            selectionEndPoint = nil
            selectionHandleDragTouchOffset = nil
        }

        func presentSelectionEditMenu(at point: CGPoint) {
            terminalEditMenuInteraction.presentEditMenu(with: UIEditMenuConfiguration(
                identifier: nil,
                sourcePoint: point
            ))
        }

        private func synchronizeSelectionHandle(
            _ handle: TerminalSelectionHandleView,
            with point: CGPoint?
        ) {
            guard let point else {
                handle.removeFromSuperview()
                return
            }
            if handle.superview == nil { addSubview(handle) }
            handle.frame = handle.frameAnchored(at: point)
        }

        /// Dragging a handle re-anchors the selection at the *other* end (a
        /// fresh press there) and drags this end to follow the touch — the
        /// same press/move/release sequence the initial long-press-drag
        /// selection already uses, just re-anchored.
        private func handleSelectionHandlePan(
            _ gesture: UIPanGestureRecognizer,
            edge: TerminalSelectionHandleView.Edge
        ) {
            guard surface != nil else { return }

            switch gesture.state {
            case .began:
                guard let movingPoint = edge == .start ? selectionStartPoint : selectionEndPoint,
                      beginSelectionEndpointDrag(edge: edge)
                else { return }
                let touch = gesture.location(in: self)
                selectionHandleDragTouchOffset = CGPoint(
                    x: movingPoint.x - touch.x,
                    y: movingPoint.y - touch.y
                )

            case .changed, .ended, .cancelled, .failed:
                guard let offset = selectionHandleDragTouchOffset else { return }
                let touch = gesture.location(in: self)
                let point = CGPoint(x: touch.x + offset.x, y: touch.y + offset.y)
                moveSelectionEndpoint(edge: edge, to: point)

                guard gesture.state != .changed else { return }
                endSelectionEndpointDrag()
                selectionHandleDragTouchOffset = nil
                presentSelectionEditMenu(at: selectionEndPoint ?? selectionStartPoint ?? point)

            default:
                break
            }
        }

        /// VoiceOver swipe on a focused handle moves that endpoint one cell row
        /// vertically (increment = down, decrement = up), matching the gesture
        /// axis. Ghostty clamps out-of-range targets at the grid edges.
        func adjustSelectionEndpoint(
            edge: TerminalSelectionHandleView.Edge,
            increment: Bool
        ) {
            guard ownsTerminalSelectionRange, surface != nil,
                  let size = surface?.size(),
                  let movingPoint = edge == .start ? selectionStartPoint : selectionEndPoint
            else { return }
            let scale = max(resolvedDisplayScale(), 1)
            let rowHeight = max(CGFloat(size.cellHeightPixels) / scale, 1)
            let target = CGPoint(
                x: movingPoint.x,
                y: movingPoint.y + (increment ? rowHeight : -rowHeight)
            )
            beginSelectionEndpointDrag(edge: edge)
            moveSelectionEndpoint(edge: edge, to: target)
            endSelectionEndpointDrag()
        }

        /// Shared press/move/release sequence for touch drags and VoiceOver
        /// adjust alike; keeping both on one path prevents the interior
        /// boundary nudge and modifier choice from drifting apart.
        /// Returns false without touching the surface when the drag cannot
        /// start (no surface or no anchor endpoint).
        @discardableResult
        private func beginSelectionEndpointDrag(edge: TerminalSelectionHandleView.Edge) -> Bool {
            guard let surface,
                  let anchor = edge == .start ? selectionEndPoint : selectionStartPoint
            else { return false }
            terminalSelectionModifiers = surface.isMouseCaptured
                ? TerminalInputModifiers.shift.ghosttyMods
                : ghostty_input_mods_e(rawValue: 0)
            // Handles sit on the outside corners of the selected cells.
            // Move half a point inward before re-anchoring so Ghostty
            // cannot floor an exact trailing boundary into the next cell.
            let interiorAnchor = CGPoint(
                x: anchor.x + (edge == .start ? -0.5 : 0.5),
                y: anchor.y + (edge == .start ? -0.5 : 0.5)
            )
            surface.sendMousePos(
                x: interiorAnchor.x,
                y: interiorAnchor.y,
                mods: terminalSelectionModifiers
            )
            surface.sendMouseButton(
                state: GHOSTTY_MOUSE_PRESS,
                button: GHOSTTY_MOUSE_LEFT,
                mods: terminalSelectionModifiers
            )
            return true
        }

        private func moveSelectionEndpoint(
            edge: TerminalSelectionHandleView.Edge,
            to point: CGPoint
        ) {
            guard let surface else { return }
            let interiorPoint = CGPoint(
                x: point.x + (edge == .start ? 0.5 : -0.5),
                y: point.y + (edge == .start ? 0.5 : -0.5)
            )
            surface.sendMousePos(
                x: interiorPoint.x,
                y: interiorPoint.y,
                mods: terminalSelectionModifiers
            )
            synchronizeSelectionHandlesWithSurface()
        }

        private func endSelectionEndpointDrag() {
            guard let surface else { return }
            surface.sendMouseButton(
                state: GHOSTTY_MOUSE_RELEASE,
                button: GHOSTTY_MOUSE_LEFT,
                mods: terminalSelectionModifiers
            )
            synchronizeSelectionHandlesWithSurface()
        }
    }
#endif
