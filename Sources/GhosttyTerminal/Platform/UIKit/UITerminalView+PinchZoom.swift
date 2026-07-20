//
//  UITerminalView+PinchZoom.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    import UIKit

    extension UITerminalView {
        private static let scaleStepThreshold: CGFloat = 0.1

        func setupPinchZoomGesture() {
            let pinch = UIPinchGestureRecognizer(
                target: self,
                action: #selector(handlePinchGesture(_:))
            )
            pinch.delegate = self
            addGestureRecognizer(pinch)
        }

        @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                lastPinchScale = gesture.scale
                pinchChangedFontSize = false

            case .changed:
                let delta = gesture.scale - lastPinchScale

                let steps = Int(delta / Self.scaleStepThreshold)
                guard steps != 0 else { return }

                lastPinchScale += CGFloat(steps) * Self.scaleStepThreshold
                pinchChangedFontSize = true
                applyFontSize(currentFontSize + Float(steps), publishesChange: true)

            case .ended, .cancelled, .failed:
                lastPinchScale = 1.0
                DispatchQueue.main.async { [weak self] in
                    self?.pinchChangedFontSize = false
                }

            default:
                break
            }
        }

        public func setTerminalFontSize(_ fontSize: Float) {
            applyFontSize(fontSize, publishesChange: false)
        }

        static func validatedFontSize(_ fontSize: Float) -> Float {
            guard fontSize.isFinite else { return 12 }
            return min(max(fontSize.rounded(), minFontSize), maxFontSize)
        }

        func applyFontSize(_ requestedSize: Float, publishesChange: Bool) {
            let fontSize = Self.validatedFontSize(requestedSize)
            guard fontSize != currentFontSize else { return }

            let difference = Int(fontSize - currentFontSize)
            if difference > 0 {
                for _ in 0 ..< difference {
                    surface?.performBindingAction("increase_font_size:1")
                }
            } else {
                for _ in 0 ..< abs(difference) {
                    surface?.performBindingAction("decrease_font_size:1")
                }
            }
            currentFontSize = fontSize
            core.recordFontSize(fontSize)
            // A font-size change alters ghostty's internal cell size without
            // changing this view's pixel bounds, so it needs its own
            // scheduled render — nothing else guarantees the resynchronized
            // grid actually gets drawn.
            core.fitToSize()
            refreshTextInputGeometry(reason: "font-size-change")
            if publishesChange {
                terminalFontSizeDidChange?(fontSize)
            }
        }

        func recordBindingFontSizeChange(_ requestedSize: Float) {
            let fontSize = Self.validatedFontSize(requestedSize)
            guard fontSize != currentFontSize else { return }
            currentFontSize = fontSize
            core.recordFontSize(fontSize)
            terminalFontSizeDidChange?(fontSize)
        }
    }
#endif
