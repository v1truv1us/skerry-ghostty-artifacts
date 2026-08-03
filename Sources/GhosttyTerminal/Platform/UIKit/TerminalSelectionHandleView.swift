//
//  TerminalSelectionHandleView.swift
//  libghostty-spm
//

#if canImport(UIKit)
    import UIKit

    /// One end of a draggable text-selection range, styled like iOS's native
    /// selection handles: the leading endpoint's knob sits above its range
    /// while the trailing endpoint's sits below. Dragging a handle adjusts
    /// only that endpoint; the owner repositions this view from Ghostty's
    /// selected-range snapshot as the gesture proceeds.
    final class TerminalSelectionHandleView: UIView {
        enum Edge {
            case start
            case end
        }

        let edge: Edge
        var onPan: ((UIPanGestureRecognizer) -> Void)?
        /// VoiceOver adjust callback: `true` for increment (swipe up), `false`
        /// for decrement. The `.adjustable` trait is only exposed because the
        /// owner wires this — an adjustable control without increment/decrement
        /// actions silently swallows the gestures.
        var onAccessibilityAdjust: ((Bool) -> Void)?

        private static let knobDiameter: CGFloat = 20
        private static let stemHeight: CGFloat = 22
        private static let stemWidth: CGFloat = 2

        static let size = CGSize(width: knobDiameter, height: stemHeight + knobDiameter)

        init(edge: Edge) {
            self.edge = edge
            super.init(frame: CGRect(origin: .zero, size: Self.size))
            backgroundColor = .clear
            isUserInteractionEnabled = true
            isAccessibilityElement = true
            accessibilityIdentifier = edge == .start
                ? "terminal-selection-leading-handle"
                : "terminal-selection-trailing-handle"
            accessibilityLabel = edge == .start ? "Selection start" : "Selection end"
            accessibilityTraits = [.adjustable]
            addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.setFillColor(tintColor.cgColor)

            let knobRect = CGRect(
                x: rect.midX - Self.knobDiameter / 2,
                y: edge == .start ? 0 : Self.stemHeight,
                width: Self.knobDiameter,
                height: Self.knobDiameter
            )
            let stemRect = CGRect(
                x: rect.midX - Self.stemWidth / 2,
                y: edge == .start ? Self.knobDiameter / 2 : 0,
                width: Self.stemWidth,
                height: Self.stemHeight + Self.knobDiameter / 2
            )
            context.fill(stemRect)
            context.fillEllipse(in: knobRect)
        }

        func frameAnchored(at point: CGPoint) -> CGRect {
            CGRect(
                x: point.x - Self.size.width / 2,
                y: point.y - (edge == .start ? Self.size.height : 0),
                width: Self.size.width,
                height: Self.size.height
            )
        }

        // The drawn knob is only 20pt wide — far under the 44pt touch floor.
        // Native handles accept touches across a larger invisible area, so
        // hit-testing expands to a square around the knob while the drawn
        // geometry stays exactly on Ghostty's selected-range anchor.
        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let knobCenter = CGPoint(
                x: bounds.midX,
                y: edge == .start
                    ? Self.knobDiameter / 2
                    : Self.stemHeight + Self.knobDiameter / 2
            )
            let hitRect = CGRect(
                x: knobCenter.x - 22,
                y: knobCenter.y - 22,
                width: 44,
                height: 44
            )
            return hitRect.contains(point)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            onPan?(gesture)
        }

        override func accessibilityIncrement() {
            onAccessibilityAdjust?(true)
        }

        override func accessibilityDecrement() {
            onAccessibilityAdjust?(false)
        }
    }
#endif
