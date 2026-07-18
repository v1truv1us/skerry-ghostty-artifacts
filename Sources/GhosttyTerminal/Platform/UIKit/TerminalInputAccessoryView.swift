//
//  TerminalInputAccessoryView.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    import UIKit

    @MainActor
    public final class TerminalInputBar: UIView {
        public private(set) weak var terminalView: UITerminalView?

        var style: TerminalInputAccessoryStyle = .default {
            didSet { refreshContent() }
        }

        private let barHeight: CGFloat = 60
        private let buttonSize: CGFloat = 44

        private lazy var blurView = UIVisualEffectView(
            effect: makeBarEffect()
        )
        private let scrollView = UIScrollView()
        private let stackView = UIStackView()
        private var blurLeadingConstraint: NSLayoutConstraint?
        private var blurTrailingConstraint: NSLayoutConstraint?
        private var blurTopConstraint: NSLayoutConstraint?
        private var blurBottomConstraint: NSLayoutConstraint?

        private lazy var escapeButton = makeKeyButton(
            title: "Escape",
            systemImage: "escape",
            key: .esc
        )
        private lazy var interruptButton = makeKeyButton(
            title: "Interrupt (Control-C)",
            systemImage: "stop.circle",
            key: .interrupt
        )
        private lazy var ctrlButton = makeModifierButton(
            title: "Control",
            systemImage: "control",
            modifier: .ctrl
        )
        private lazy var altButton = makeModifierButton(
            title: "Option",
            systemImage: "option",
            modifier: .alt
        )
        private lazy var cmdButton = makeModifierButton(
            title: "Command",
            systemImage: "command",
            modifier: .command
        )
        private lazy var tabButton = makeKeyButton(
            title: "Tab",
            systemImage: "arrow.right.to.line",
            key: .tab
        )
        private lazy var endButton = makeKeyButton(
            title: "End",
            key: .end
        )
        private lazy var leftButton = makeKeyButton(
            title: "Left",
            systemImage: "arrowshape.left",
            key: .arrowLeft
        )
        private lazy var upButton = makeKeyButton(
            title: "Up",
            systemImage: "arrowshape.up",
            key: .arrowUp
        )
        private lazy var downButton = makeKeyButton(
            title: "Down",
            systemImage: "arrowshape.down",
            key: .arrowDown
        )
        private lazy var rightButton = makeKeyButton(
            title: "Right",
            systemImage: "arrowshape.right",
            key: .arrowRight
        )
        private lazy var pasteButton = makeKeyButton(
            title: "Paste",
            systemImage: "doc.on.clipboard",
            key: .paste
        )
        private var customActionButtons: [AccessoryButton] = []
        private lazy var customActionDivider = makeDivider()

        private lazy var symbolButtons: [AccessoryButton] = Self.symbols.map { symbol in
            makeKeyButton(title: symbol, key: .symbol(symbol))
        }

        private lazy var hideKeyboardButton: AccessoryButton = {
            let button = AccessoryButton(size: buttonSize) { [weak self] in
                self?.eligibleTerminalView?.window?.endEditing(true)
            }
            button.accessibilityLabel = "Hide Keyboard"
            button.setImage(UIImage(systemName: "keyboard.chevron.compact.down"), for: .normal)
            return button
        }()

        private lazy var modifierButtons: [(TerminalStickyModifierState.Modifier, AccessoryButton)] = [
            (.ctrl, ctrlButton),
            (.alt, altButton),
            (.command, cmdButton),
        ]

        public init(terminalView: UITerminalView? = nil) {
            self.terminalView = terminalView
            super.init(
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 0,
                    height: Self.preferredHeight(for: barHeight)
                )
            )
            autoresizingMask = .flexibleWidth
            setupViews()
            applyBarChrome()
            refreshContent()
            installChangeHandlers()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        public override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: preferredHeight)
        }

        public func setTerminalView(_ terminalView: UITerminalView?) {
            guard self.terminalView !== terminalView else {
                refreshContent()
                return
            }
            self.terminalView?.setStickyModifierChangeHandler(nil)
            self.terminalView?.hostInputBarContentDidChange = nil
            self.terminalView = terminalView
            installChangeHandlers()
            refreshContent()
        }

        private var eligibleTerminalView: UITerminalView? {
            guard let terminalView, terminalView.isResponderEligible else { return nil }
            return terminalView
        }

        private func installChangeHandlers() {
            terminalView?.setStickyModifierChangeHandler { [weak self] in
                self?.refreshContent()
            }
            terminalView?.hostInputBarContentDidChange = { [weak self] in
                self?.refreshContent()
            }
        }

        func refreshContent() {
            refreshCustomActionButtons()
            let hasMarkedText = terminalView?.inputHandler.hasMarkedText ?? false
            let ctrlActivation = terminalView?.stickyModifiers.ctrl ?? .inactive
            let altActivation = terminalView?.stickyModifiers.alt ?? .inactive
            let cmdActivation = terminalView?.stickyModifiers.command ?? .inactive

            interruptButton.applyRegularStyle(style)
            escapeButton.applyRegularStyle(style)
            tabButton.applyRegularStyle(style)
            endButton.applyRegularStyle(style)
            leftButton.applyRegularStyle(style)
            upButton.applyRegularStyle(style)
            downButton.applyRegularStyle(style)
            rightButton.applyRegularStyle(style)
            pasteButton.applyRegularStyle(style)
            for (button, action) in zip(customActionButtons, terminalView?.inputAccessoryActions ?? []) {
                button.applyModifierStyle(
                    action.isSelected ? .armed : .inactive,
                    isDisabled: false,
                    style: style
                )
                button.accessibilityValue = action.isSelected ? "Active" : "Inactive"
            }
            hideKeyboardButton.applyRegularStyle(style)
            symbolButtons.forEach { $0.applyRegularStyle(style) }

            ctrlButton.applyModifierStyle(ctrlActivation, isDisabled: hasMarkedText, style: style)
            altButton.applyModifierStyle(altActivation, isDisabled: hasMarkedText, style: style)
            cmdButton.applyModifierStyle(cmdActivation, isDisabled: hasMarkedText, style: style)
        }

        private func setupViews() {
            backgroundColor = .clear

            blurView.translatesAutoresizingMaskIntoConstraints = false
            blurView.clipsToBounds = true
            addSubview(blurView)

            let leading = blurView.leadingAnchor.constraint(equalTo: leadingAnchor)
            let trailing = blurView.trailingAnchor.constraint(equalTo: trailingAnchor)
            let top = blurView.topAnchor.constraint(equalTo: topAnchor)
            let bottom = blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
            blurLeadingConstraint = leading
            blurTrailingConstraint = trailing
            blurTopConstraint = top
            blurBottomConstraint = bottom

            NSLayoutConstraint.activate([
                leading,
                trailing,
                top,
                bottom,
                blurView.heightAnchor.constraint(equalToConstant: barHeight),
            ])

            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = true
            scrollView.clipsToBounds = true
            blurView.contentView.addSubview(scrollView)

            blurView.contentView.addSubview(hideKeyboardButton)
            NSLayoutConstraint.activate([
                hideKeyboardButton.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -10),
                hideKeyboardButton.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            ])

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: hideKeyboardButton.leadingAnchor, constant: -8),
                scrollView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            ])

            stackView.translatesAutoresizingMaskIntoConstraints = false
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.spacing = 8
            scrollView.addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 10),
                stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -10),
                stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            ])

            addArrangedViews([
                customActionDivider,
                interruptButton,
                escapeButton,
                ctrlButton,
                altButton,
                cmdButton,
                makeDivider(),
                tabButton,
                endButton,
                leftButton,
                upButton,
                downButton,
                rightButton,
                makeDivider(),
            ] + symbolButtons + [
                pasteButton,
            ])
        }

        private func refreshCustomActionButtons() {
            for button in customActionButtons {
                stackView.removeArrangedSubview(button)
                button.removeFromSuperview()
            }

            customActionButtons = (terminalView?.inputAccessoryActions ?? []).map { action in
                let button = AccessoryButton(size: buttonSize) { [weak self] in
                    guard let terminalView = self?.eligibleTerminalView else { return }
                    terminalView.inputAccessoryActions.first { $0.id == action.id }?.handler()
                }
                button.accessibilityLabel = action.accessibilityLabel
                let imageName = action.isSelected
                    ? action.selectedSystemImage ?? action.systemImage
                    : action.systemImage
                button.setImage(UIImage(systemName: imageName), for: .normal)
                return button
            }
            customActionDivider.isHidden = customActionButtons.isEmpty
            for button in customActionButtons.reversed() {
                stackView.insertArrangedSubview(button, at: 0)
            }
        }

        private func addArrangedViews(_ views: [UIView]) {
            views.forEach { stackView.addArrangedSubview($0) }
        }

        private func makeDivider() -> UIView {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = .secondaryLabel.withAlphaComponent(0.28)
            view.layer.cornerRadius = 3
            NSLayoutConstraint.activate([
                view.widthAnchor.constraint(equalToConstant: 6),
                view.heightAnchor.constraint(equalToConstant: 6),
            ])
            return view
        }

        private func makeModifierButton(
            title: String,
            systemImage: String,
            modifier: TerminalStickyModifierState.Modifier
        ) -> AccessoryButton {
            let button = AccessoryButton(size: buttonSize) { [weak self] in
                self?.eligibleTerminalView?.stickyModifiers.toggle(modifier)
            }
            button.accessibilityLabel = title
            button.setImage(UIImage(systemName: systemImage), for: .normal)
            return button
        }

        private func makeKeyButton(
            title: String,
            systemImage: String? = nil,
            key: TerminalInputBarKey
        ) -> AccessoryButton {
            let button = AccessoryButton(size: buttonSize) { [weak self] in
                self?.eligibleTerminalView?.handleInputBarKey(key)
            }
            button.accessibilityLabel = title

            if let systemImage {
                button.setImage(UIImage(systemName: systemImage), for: .normal)
            } else {
                var configuration = UIButton.Configuration.plain()
                configuration.baseForegroundColor = .label
                configuration.title = title
                configuration.contentInsets = .zero
                configuration.attributedTitle = AttributedString(
                    title,
                    attributes: AttributeContainer([
                        .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                    ])
                )
                button.configuration = configuration
            }

            return button
        }

        private var preferredHeight: CGFloat {
            Self.preferredHeight(for: barHeight)
        }

        private var currentOuterPadding: UIEdgeInsets {
            if #available(iOS 26, *) {
                UIEdgeInsets(top: 0, left: 8, bottom: 8, right: 8)
            } else {
                .zero
            }
        }

        private func makeBarEffect() -> UIVisualEffect {
            if #available(iOS 26, *) {
                let effect = UIGlassEffect(style: .regular)
                effect.isInteractive = true
                return effect
            } else {
                return UIBlurEffect(style: .systemUltraThinMaterial)
            }
        }

        private func applyBarChrome() {
            let padding = currentOuterPadding
            blurLeadingConstraint?.constant = padding.left
            blurTrailingConstraint?.constant = -padding.right
            blurTopConstraint?.constant = padding.top
            blurBottomConstraint?.isActive = !isFloatingBarLayout

            blurView.effect = makeBarEffect()
            blurView.layer.cornerCurve = .continuous
            blurView.layer.cornerRadius = if #available(iOS 26, *) {
                barHeight / 2
            } else {
                0
            }

            invalidateIntrinsicContentSize()
        }

        private var isFloatingBarLayout: Bool {
            if #available(iOS 26, *) {
                true
            } else {
                false
            }
        }

        private static func preferredHeight(for barHeight: CGFloat) -> CGFloat {
            if #available(iOS 26, *) {
                barHeight + 8
            } else {
                barHeight
            }
        }

        private static let symbols: [String] = []
    }

    private final class AccessoryButton: UIButton {
        private let size: CGFloat
        private let handler: () -> Void
        private let lockIndicator = UIView()
        private let selectionFeedback = UISelectionFeedbackGenerator()

        init(size: CGFloat, handler: @escaping () -> Void) {
            self.size = size
            self.handler = handler
            super.init(frame: .zero)

            translatesAutoresizingMaskIntoConstraints = false
            layer.cornerRadius = size / 2
            layer.cornerCurve = .continuous
            clipsToBounds = true

            tintColor = .label
            backgroundColor = UIColor.systemGray5.withAlphaComponent(0.92)

            titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            imageView?.contentMode = .scaleAspectFit

            NSLayoutConstraint.activate([
                widthAnchor.constraint(equalToConstant: size),
                heightAnchor.constraint(equalToConstant: size),
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
