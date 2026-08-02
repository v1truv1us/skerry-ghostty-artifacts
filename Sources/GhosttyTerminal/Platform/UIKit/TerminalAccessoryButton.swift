//
//  TerminalAccessoryButton.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    import UIKit

    final class AccessoryButton: UIButton {
        private(set) var systemImageName: String?
        private let handler: () -> Void
        private let lockIndicator = UIView()
        private let selectionFeedback = UISelectionFeedbackGenerator()

        init(width: CGFloat, height: CGFloat, handler: @escaping () -> Void) {
            self.handler = handler
            super.init(frame: .zero)

            translatesAutoresizingMaskIntoConstraints = false
            // A low-radius rounded rectangle keeps the toolbar visually light
            // without turning every key into a large circle. Width remains
            // generous for thumb targeting while the shorter height returns
            // terminal space above the keyboard.
            layer.cornerRadius = min(10, height / 2)
            layer.cornerCurve = .continuous
            clipsToBounds = true

            tintColor = .label
            backgroundColor = UIColor.systemGray5.withAlphaComponent(0.92)

            titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            imageView?.contentMode = .scaleAspectFit

            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: width),
                heightAnchor.constraint(equalToConstant: height),
            ])

            lockIndicator.translatesAutoresizingMaskIntoConstraints = false
            lockIndicator.backgroundColor = tintColor
            lockIndicator.layer.cornerRadius = 1.5
            lockIndicator.isHidden = true
            addSubview(lockIndicator)

            NSLayoutConstraint.activate([
                lockIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                lockIndicator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
                lockIndicator.widthAnchor.constraint(equalToConstant: 14),
                lockIndicator.heightAnchor.constraint(equalToConstant: 3),
            ])

            addAction(UIAction { [weak self] _ in
                self?.selectionFeedback.selectionChanged()
                self?.handler()
            }, for: .touchUpInside)
            addAction(UIAction { [weak self] _ in
                self?.selectionFeedback.prepare()
            }, for: .touchDown)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setSystemImage(named name: String) {
            systemImageName = name
            setImage(UIImage(systemName: name), for: .normal)
        }

        func applyRegularStyle(_ style: TerminalInputAccessoryStyle) {
            isEnabled = true
            alpha = 1
            tintColor = style.regularForeground
            backgroundColor = style.regularBackground
            lockIndicator.isHidden = true
            lockIndicator.backgroundColor = tintColor
            configuration?.baseForegroundColor = tintColor
        }

        func applyModifierStyle(
            _ activation: TerminalStickyModifierState.Activation,
            isDisabled: Bool,
            style: TerminalInputAccessoryStyle
        ) {
            isEnabled = !isDisabled
            alpha = isDisabled && activation == .inactive ? 0.45 : 1

            let isActive = activation != .inactive
            tintColor = isActive ? style.activeForeground : style.regularForeground
            backgroundColor = isActive ? style.activeBackground : style.regularBackground
            lockIndicator.isHidden = activation != .locked
            lockIndicator.backgroundColor = tintColor
            configuration?.baseForegroundColor = tintColor
        }
    }
#endif
