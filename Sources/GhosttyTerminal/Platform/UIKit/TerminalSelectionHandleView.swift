//
//  TerminalSelectionHandleView.swift
//  libghostty-spm
//

#if canImport(UIKit)
    import UIKit

    /// One end of a draggable text-selection range, styled like iOS's native
    /// selection handles: a small circle with a vertical stem. Dragging a
    /// handle adjusts only that endpoint; the owner repositions this view as
    /// the gesture proceeds.
    final class TerminalSelectionHandleView: UIView {
        enum Edge {
            case start
            case end
        }

        let edge: Edge
        var onPan: ((UIPanGestureRecognizer) -> Void)?

        private static let knobDiameter: CGFloat = 20
        private static let stemHeight: CGFloat = 22
        private static let stemWidth: CGFloat = 2

        static let size = CGSize(width: knobDiameter, height: stemHeight + knobDiameter)

        init(edge: Edge) {
            self.edge = edge
            super.init(frame: CGRect(origin: .zero, size: Self.size))
            backgroundColor = .clear
            isUserInteractionEnabled = true
            addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.setFillColor(tintColor.cgColor)

            let stemRect = CGRect(
                x: rect.midX - Self.stemWidth / 2,
                y: 0,
                width: Self.stemWidth,
                height: Self.stemHeight
            )
            context.fill(stemRect)

            let knobRect = CGRect(
                x: rect.midX - Self.knobDiameter / 2,
                y: Self.stemHeight,
                width: Self.knobDiameter,
                height: Self.knobDiameter
            )
            context.fillEllipse(in: knobRect)
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            onPan?(gesture)
        }
    }
#endif
