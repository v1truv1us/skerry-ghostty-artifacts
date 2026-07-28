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

        // Read via `Self.` before `super.init()` runs (the frame height
        // argument), so these must stay static rather than instance state.
        private static let rowHeight: CGFloat = 60
        private static let interRowSpacing: CGFloat = 6
        private static var barHeight: CGFloat { rowHeight * 2 + interRowSpacing }
        private let buttonSize: CGFloat = 44

        private lazy var blurView = UIVisualEffectView(
            effect: makeBarEffect()
        )
        private let rowsStackView = UIStackView()
        // Row nearest the keyboard: navigation cluster + Skerry's custom
        // actions. This is the most-reached-for row, so it sits where thumb
        // travel from the keyboard is shortest.
        private let navScrollView = UIScrollView()
        private let navStackView = UIStackView()
        // Row farthest from the keyboard: modifiers, Esc, Tab, Interrupt,
        // Paste — used less often than navigation, per owner confirmation.
        private let commandScrollView = UIScrollView()
        private let commandStackView = UIStackView()
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
        private lazy var homeButton = makeKeyButton(
            title: "Home",
            key: .home
        )
        private lazy var pageUpButton = makeKeyButton(
            title: "PgUp",
            accessibilityLabel: "Page Up",
            key: .pageUp
        )
        private lazy var endButton = makeKeyButton(
            title: "End",
            key: .end
        )
        private lazy var pageDownButton = makeKeyButton(
            title: "PgDn",
            accessibilityLabel: "Page Down",
            key: .pageDown
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
                    height: Self.preferredHeight(for: Self.barHeight)
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
            homeButton.applyRegularStyle(style)
            pageUpButton.applyRegularStyle(style)
            endButton.applyRegularStyle(style)
            pageDownButton.applyRegularStyle(style)
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
                blurView.heightAnchor.constraint(equalToConstant: Self.barHeight),
            ])

            rowsStackView.translatesAutoresizingMaskIntoConstraints = false
            rowsStackView.axis = .vertical
            rowsStackView.spacing = Self.interRowSpacing
            rowsStackView.distribution = .fillEqually
            blurView.contentView.addSubview(rowsStackView)

            blurView.contentView.addSubview(hideKeyboardButton)
            NSLayoutConstraint.activate([
                hideKeyboardButton.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -10),
                hideKeyboardButton.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            ])

            NSLayoutConstraint.activate([
                rowsStackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
                rowsStackView.trailingAnchor.constraint(equalTo: hideKeyboardButton.leadingAnchor, constant: -8),
                rowsStackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
                rowsStackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
            ])

            // Command row on top, nav row on bottom: subview order in a
            // vertical stack also drives default VoiceOver traversal, so
            // VoiceOver reaches the command row first — the reverse of touch
            // priority. Accepted trade-off; nav still wins the no-scroll
            // zone nearest the keyboard for touch, which is what was asked
            // for.
            setupRow(scrollView: commandScrollView, stackView: commandStackView, in: rowsStackView)
            setupRow(scrollView: navScrollView, stackView: navStackView, in: rowsStackView)

            addArrangedViews([
                interruptButton,
                escapeButton,
                ctrlButton,
                altButton,
                cmdButton,
                makeDivider(),
                tabButton,
            ] + symbolButtons + [
                pasteButton,
            ], to: commandStackView)

            // Navigation cluster first (Home/PgUp bracket the arrows,
            // PgDn/End bracket the other side — mirrors a physical extended
            // keyboard's nav block), custom actions after. The nav cluster
            // alone is wider than the visible bar at rest; this ordering
            // keeps Home/PgUp/the arrows scroll-free since they're reached
            // for repeatedly while editing, at the cost of custom actions
            // (usually a single tap) needing a short scroll.
            addArrangedViews([
                homeButton,
                pageUpButton,
                leftButton,
                upButton,
                downButton,
                rightButton,
                pageDownButton,
                endButton,
                customActionDivider,
            ], to: navStackView)
        }

        private func setupRow(scrollView: UIScrollView, stackView: UIStackView, in container: UIStackView) {
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = true
            scrollView.clipsToBounds = true
            container.addArrangedSubview(scrollView)

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
        }

        private func refreshCustomActionButtons() {
            for button in customActionButtons {
                navStackView.removeArrangedSubview(button)
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
            // Appended after the nav cluster (not inserted at index 0) —
            // see the ordering rationale in setupViews().
            for button in customActionButtons {
                navStackView.addArrangedSubview(button)
            }
        }

        private func addArrangedViews(_ views: [UIView], to stackView: UIStackView) {
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
            accessibilityLabel: String? = nil,
            key: TerminalInputBarKey
        ) -> AccessoryButton {
            let button = AccessoryButton(size: buttonSize) { [weak self] in
                self?.eligibleTerminalView?.handleInputBarKey(key)
            }
            button.accessibilityLabel = accessibilityLabel ?? title

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
            Self.preferredHeight(for: Self.barHeight)
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
                // Cap at a single row's radius rather than half the new
                // two-row height, so the taller bar keeps the same pill
                // curvature as before instead of ballooning it.
                min(Self.barHeight / 2, Self.rowHeight / 2)
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
#endif
