//
//  UITerminalView+Lifecycle.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/17.
//

#if canImport(UIKit)
    import UIKit

    public extension UITerminalView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            TerminalDebugLog.log(
                .lifecycle,
                "didMoveToWindow attached=\(window != nil)"
            )
            updateDisplayScale()
            if window != nil {
                // SwiftUI/UIKit can temporarily detach and reattach the
                // terminal view while diffing the view hierarchy. Rebuilding
                // on every reattach discards Ghostty's scrollback/state (the
                // session cannot replay it), so only create a surface when
                // one does not already exist; otherwise just repaint.
                if surface == nil {
                    core.rebuildIfReady()
                } else {
                    core.requestImmediateTick()
                }
                updateColorScheme()
                core.startDisplayLink()
                // Defer sublayer frame and metrics sync to the next runloop
                // so that AutoLayout has resolved final bounds. The earlier
                // requestImmediateTick() above can already have consumed the
                // pending-tick flag against the pre-reattach bounds (e.g. a
                // SwiftUI detach/reattach mid-rotation), so this deferred
                // sync must schedule its own tick rather than rely on that
                // one — otherwise the surface keeps showing a frame rendered
                // against stale bounds until unrelated output arrives.
                DispatchQueue.main.async { [weak self] in
                    guard let self, window != nil else { return }
                    updateSublayerFrames()
                    core.fitToSize()
                }
            } else {
                core.stopDisplayLink()
                core.setFocus(false)
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            TerminalDebugLog.log(
                .metrics,
                "layoutSubviews bounds=\(NSCoder.string(for: bounds))"
            )
            updateSublayerFrames()
            // Resizing can replace Ghostty's IOSurface. Synchronizing its new
            // grid without scheduling the required full render leaves an idle
            // terminal black after rotation until unrelated output arrives.
            // Keep resize and repaint one lifecycle operation while retaining
            // the same surface/controller and their terminal state. UIKit can
            // invoke layoutSubviews for an ancestor's relayout even when this
            // view's own bounds are unchanged (e.g. a sibling split-divider
            // drag), so use the size-gated variant to skip the FFI resize and
            // forced redraw when nothing actually moved.
            core.fitToSizeIfChanged()
        }

        internal func resolvedDisplayScale() -> CGFloat {
            if let screen = window?.screen {
                return screen.nativeScale
            }
            if traitCollection.displayScale > 0 {
                return traitCollection.displayScale
            }
            return UIScreen.main.nativeScale
        }

        internal func updateDisplayScale() {
            let scale = resolvedDisplayScale()
            TerminalDebugLog.log(
                .metrics,
                "updateDisplayScale scale=\(String(format: "%.2f", scale))"
            )
            contentScaleFactor = scale
            layer.contentsScale = scale
            updateSublayerFrames()
        }

        internal func updateSublayerFrames() {
            let scale = resolvedDisplayScale()
            contentScaleFactor = scale
            layer.contentsScale = scale
            guard let sublayers = layer.sublayers else { return }
            for sublayer in sublayers {
                sublayer.frame = bounds
                sublayer.contentsScale = scale
            }
        }

        internal func enforceSublayerScale() {
            let scale = resolvedDisplayScale()
            guard let sublayers = layer.sublayers else { return }
            for sublayer in sublayers {
                if sublayer.contentsScale != scale {
                    sublayer.contentsScale = scale
                }
                if sublayer.frame != bounds {
                    sublayer.frame = bounds
                }
            }
        }

        func fitToSize() {
            core.fitToSize()
        }

        /// Keeps the terminal surface alive while pausing rendering for hidden panes.
        func setDisplayVisible(_ visible: Bool) {
            core.setDisplayVisible(visible)
        }

        /// Forces an out-of-band redraw of the current grid. iOS may
        /// invalidate the Metal layer's contents while the app is suspended,
        /// and a demand-ticked renderer has no other reason to draw an idle
        /// pane on return.
        func requestRepaint() {
            core.requestImmediateTick()
        }

        override func traitCollectionDidChange(
            _ previousTraitCollection: UITraitCollection?
        ) {
            super.traitCollectionDidChange(previousTraitCollection)
            updateDisplayScale()
            if traitCollection.hasDifferentColorAppearance(
                comparedTo: previousTraitCollection
            ) {
                updateColorScheme()
            }
        }

        internal func updateColorScheme() {
            let style = traitCollection.userInterfaceStyle
            let scheme: TerminalColorScheme = style == .dark ? .dark : .light
            TerminalDebugLog.log(.lifecycle, "updateColorScheme scheme=\(scheme)")
            surface?.setColorScheme(scheme.ghosttyValue)
            controller?.setColorScheme(scheme)
        }

        @discardableResult
        override func becomeFirstResponder() -> Bool {
            let result = super.becomeFirstResponder()
            core.setFocus(true)
            return result
        }

        @discardableResult
        override func resignFirstResponder() -> Bool {
            let result = super.resignFirstResponder()
            core.setFocus(false)
            return result
        }
    }
#endif
