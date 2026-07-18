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
        }

        /// `start`/`end` are the same view-space points already sent to
        /// Ghostty via `sendMousePos` — not read back from it.
        func showSelectionHandles(start: CGPoint, end: CGPoint) {
            selectionStartPoint = start
            selectionEndPoint = end

            if startSelectionHandle.superview == nil { addSubview(startSelectionHandle) }
            if endSelectionHandle.superview == nil { addSubview(endSelectionHandle) }
            positionSelectionHandle(startSelectionHandle, at: start)
            positionSelectionHandle(endSelectionHandle, at: end)
        }

        func hideSelectionHandles() {
            startSelectionHandle.removeFromSuperview()
            endSelectionHandle.removeFromSuperview()
            selectionStartPoint = nil
            selectionEndPoint = nil
            selectionHandleDragOrigin = nil
        }

        func presentSelectionEditMenu(at point: CGPoint) {
            terminalEditMenuInteraction.presentEditMenu(with: UIEditMenuConfiguration(
                identifier: nil,
                sourcePoint: point
            ))
        }

        private func positionSelectionHandle(_ handle: TerminalSelectionHandleView, at point: CGPoint) {
            handle.frame = CGRect(
                x: point.x - TerminalSelectionHandleView.size.width / 2,
                y: point.y,
                width: TerminalSelectionHandleView.size.width,
                height: TerminalSelectionHandleView.size.height
            )
        }

        /// Dragging a handle re-anchors the selection at the *other* end (a
        /// fresh press there) and drags this end to follow the touch — the
        /// same press/move/release sequence the initial long-press-drag
        /// selection already uses, just re-anchored.
        private func handleSelectionHandlePan(
            _ gesture: UIPanGestureRecognizer,
            edge: TerminalSelectionHandleView.Edge
        ) {
            guard let surface else { return }

            switch gesture.state {
            case .began:
                guard let anchor = edge == .start ? selectionEndPoint : selectionStartPoint
                else { return }
                terminalSelectionModifiers = surface.isMouseCaptured
                    ? TerminalInputModifiers.shift.ghosttyMods
                    : ghostty_input_mods_e(rawValue: 0)
                surface.sendMousePos(x: anchor.x, y: anchor.y, mods: terminalSelectionModifiers)
                surface.sendMouseButton(
                    state: GHOSTTY_MOUSE_PRESS,
                    button: GHOSTTY_MOUSE_LEFT,
                    mods: terminalSelectionModifiers
                )
                selectionHandleDragOrigin = edge == .start ? selectionStartPoint : selectionEndPoint

            case .changed, .ended, .cancelled, .failed:
                guard let origin = selectionHandleDragOrigin else { return }
                let translation = gesture.translation(in: self)
                let point = CGPoint(x: origin.x + translation.x, y: origin.y + translation.y)
                surface.sendMousePos(x: point.x, y: point.y, mods: terminalSelectionModifiers)

                if edge == .start {
                    selectionStartPoint = point
                } else {
                    selectionEndPoint = point
                }
                positionSelectionHandle(edge == .start ? startSelectionHandle : endSelectionHandle, at: point)

                guard gesture.state != .changed else { return }
                surface.sendMouseButton(
                    state: GHOSTTY_MOUSE_RELEASE,
                    button: GHOSTTY_MOUSE_LEFT,
                    mods: terminalSelectionModifiers
                )
                selectionHandleDragOrigin = nil
                presentSelectionEditMenu(at: point)

            default:
                break
            }
        }
    }
#endif
