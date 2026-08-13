//
//  TerminalInputAccessoryView.swift
//  libghostty-spm
//

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
    import UIKit
    import UniformTypeIdentifiers

    @MainActor
    public final class TerminalInputBar: UIView {
        public private(set) weak var terminalView: UITerminalView?

        var style: TerminalInputAccessoryStyle = .default {
            didSet {
                // UIPasteControl copies its configuration at init, so a style
                // change rebuilds the control rather than mutating it.
                pasteControl = makePasteControl()
                rebuildCommandRow()
                refreshContent()
            }
        }

        /// A hardware keyboard duplicates every key row; slim mode keeps only
        /// the host's custom actions and Hide Keyboard so the bar stops
        /// covering terminal output with physical-key duplicates.
        var isSlimForHardwareKeyboard = false {
            didSet {
                guard isSlimForHardwareKeyboard != oldValue else { return }
                applySlimMode()
            }
        }

        // Read via `Self.` before `super.init()` runs (the frame height
        // argument), so these must stay static rather than instance state.
        // Keep the 44pt horizontal target but use a shorter rounded rectangle
        // and a small amount of row breathing room. The prior 44x44 circles
        // consumed terminal height without improving horizontal reach.
        private static let rowHeight: CGFloat = 36
        private static let interRowSpacing: CGFloat = 2
        private static let contentVerticalInset: CGFloat = 3
        private static var barHeight: CGFloat {
            rowHeight * 2 + interRowSpacing + contentVerticalInset * 2
        }
        private static var slimBarHeight: CGFloat {
            rowHeight + contentVerticalInset * 2
        }
        private let buttonWidth: CGFloat = 44
        private let buttonHeight: CGFloat = 32

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
        // Paste, or the mode-switched extended keys. Swapping this row rather
        // than adding a third one preserves the compact terminal viewport.
        private let commandScrollView = UIScrollView()
        private let commandStackView = UIStackView()
        private var showsExtendedKeys = false
        private var blurLeadingConstraint: NSLayoutConstraint?
        private var blurTrailingConstraint: NSLayoutConstraint?
        private var blurTopConstraint: NSLayoutConstraint?
        private var blurBottomConstraint: NSLayoutConstraint?
        private var blurHeightConstraint: NSLayoutConstraint?
        // Both rows hide their scroll indicators, so edge fades are the only
        // discoverability signal for off-screen keys (PgDn/End, custom
        // actions, Paste).
        private lazy var navLeadingFade = EdgeFadeView(edge: .leading)
        private lazy var navTrailingFade = EdgeFadeView(edge: .trailing)
        private lazy var commandLeadingFade = EdgeFadeView(edge: .leading)
        private lazy var commandTrailingFade = EdgeFadeView(edge: .trailing)

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
        private lazy var moreKeysButton: AccessoryButton = {
            let button = makeAccessoryButton { [weak self] in
                self?.toggleExtendedKeyMode()
            }
            button.accessibilityLabel = "More Keys"
            button.accessibilityHint = "Shows Shift, Insert, Forward Delete, and function keys."
            setTextTitle("Fn", on: button)
            return button
        }()
        private lazy var shiftButton = makeModifierButton(
            title: "Shift",
            systemImage: "shift",
            modifier: .shift
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
        private lazy var cmdButton: AccessoryButton = {
            let button = makeModifierButton(
                title: "Command",
                systemImage: "command",
                modifier: .command
            )
            button.accessibilityHint = "Tap once, then tap a terminal link to open it. Double-tap to lock Command."
            return button
        }()
        private lazy var tabButton = makeKeyButton(
            title: "Tab",
            systemImage: "arrow.right.to.line",
            key: .tab
        )
        private lazy var backtabButton = makeKeyButton(
            title: "Backtab",
            systemImage: "arrow.left.to.line",
            key: .backtab
        )
        private lazy var insertButton = makeKeyButton(
            title: "Ins",
            accessibilityLabel: "Insert",
            key: .insert
        )
        private lazy var deleteForwardButton = makeKeyButton(
            title: "Del",
            accessibilityLabel: "Forward Delete",
            key: .deleteForward
        )
        private lazy var functionButtons: [AccessoryButton] = (1 ... 12).map { number in
            makeKeyButton(title: "F\(number)", key: .function(number))
        }
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
            systemImage: "arrowtriangle.left.fill",
            key: .arrowLeft
        )
        private lazy var upButton = makeKeyButton(
            title: "Up",
            systemImage: "arrowtriangle.up.fill",
            key: .arrowUp
        )
        private lazy var downButton = makeKeyButton(
            title: "Down",
            systemImage: "arrowtriangle.down.fill",
            key: .arrowDown
        )
        private lazy var rightButton = makeKeyButton(
            title: "Right",
            systemImage: "arrowtriangle.right.fill",
            key: .arrowRight
        )
        // UIPasteControl instead of a plain button: the tap itself grants
        // pasteboard access, so reading the pasteboard never triggers the
        // system paste-permission banner. Its configuration is copied at
        // init, so a style change rebuilds the control (see style.didSet).
        // Internal (not private) so tests can verify the paste-target wiring.
        lazy var pasteControl = makePasteControl()
        private var customActionButtons: [AccessoryButton] = []
        private lazy var customActionDivider = makeDivider()
        private lazy var commandDivider = makeDivider()

        private lazy var symbolButtons: [AccessoryButton] = Self.symbols.map { symbol in
            makeKeyButton(title: symbol, key: .symbol(symbol))
        }

        private lazy var hideKeyboardButton: AccessoryButton = {
            let button = makeAccessoryButton { [weak self] in
                self?.eligibleTerminalView?.window?.endEditing(true)
            }
            button.accessibilityLabel = "Hide Keyboard"
            button.setSystemImage(named: "keyboard.chevron.compact.down")
            return button
        }()

        private lazy var modifierButtons: [(TerminalStickyModifierState.Modifier, AccessoryButton)] = [
            (.shift, shiftButton),
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
            let shiftActivation = terminalView?.stickyModifiers.shift ?? .inactive
            let ctrlActivation = terminalView?.stickyModifiers.ctrl ?? .inactive
            let altActivation = terminalView?.stickyModifiers.alt ?? .inactive
            let cmdActivation = terminalView?.stickyModifiers.command ?? .inactive

            interruptButton.applyRegularStyle(style)
            moreKeysButton.applyModifierStyle(
                showsExtendedKeys ? .armed : .inactive,
                isDisabled: false,
                style: style
            )
            moreKeysButton.accessibilityValue = showsExtendedKeys ? "Expanded" : "Collapsed"
            escapeButton.applyRegularStyle(style)
            tabButton.applyRegularStyle(style)
            insertButton.applyRegularStyle(style)
            deleteForwardButton.applyRegularStyle(style)
            functionButtons.forEach { $0.applyRegularStyle(style) }
            homeButton.applyRegularStyle(style)
            pageUpButton.applyRegularStyle(style)
            endButton.applyRegularStyle(style)
            pageDownButton.applyRegularStyle(style)
            leftButton.applyRegularStyle(style)
            upButton.applyRegularStyle(style)
            downButton.applyRegularStyle(style)
            rightButton.applyRegularStyle(style)
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

            let activations = [shiftActivation, ctrlActivation, altActivation, cmdActivation]
            for ((_, button), activation) in zip(modifierButtons, activations) {
                button.applyModifierStyle(activation, isDisabled: hasMarkedText, style: style)
                // Sticky state is otherwise tint-only; VoiceOver must speak
                // whether a modifier is armed, locked, or off.
                button.accessibilityValue = switch activation {
                case .inactive: nil
                case .armed: "Armed"
                case .locked: "Locked"
                }
                if button.accessibilityHint == nil {
                    button.accessibilityHint = "Tap to apply to the next key. Double-tap to lock."
                }
            }
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

            let blurHeight = blurView.heightAnchor.constraint(equalToConstant: Self.barHeight)
            blurHeightConstraint = blurHeight
            NSLayoutConstraint.activate([
                leading,
                trailing,
                top,
                bottom,
                blurHeight,
            ])

            rowsStackView.translatesAutoresizingMaskIntoConstraints = false
            rowsStackView.axis = .vertical
            rowsStackView.spacing = Self.interRowSpacing
            rowsStackView.distribution = .fillEqually
            blurView.contentView.addSubview(rowsStackView)

            blurView.contentView.addSubview(hideKeyboardButton)
            NSLayoutConstraint.activate([
                hideKeyboardButton.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -10),
            ])

            NSLayoutConstraint.activate([
                rowsStackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
                rowsStackView.trailingAnchor.constraint(equalTo: hideKeyboardButton.leadingAnchor, constant: -8),
                rowsStackView.topAnchor.constraint(
                    equalTo: blurView.contentView.topAnchor,
                    constant: Self.contentVerticalInset
                ),
                rowsStackView.bottomAnchor.constraint(
                    equalTo: blurView.contentView.bottomAnchor,
                    constant: -Self.contentVerticalInset
                ),
            ])

            // Command row on top, nav row on bottom: subview order in a
            // vertical stack also drives default VoiceOver traversal, so
            // VoiceOver reaches the command row first — the reverse of touch
            // priority. Accepted trade-off; nav still wins the no-scroll
            // zone nearest the keyboard for touch, which is what was asked
            // for.
            setupRow(scrollView: commandScrollView, stackView: commandStackView, in: rowsStackView)
            // Test-only hook: Paste sits at the far end of this row, so UI
            // tests need a stable identifier to scroll it into view.
            commandScrollView.accessibilityIdentifier = "terminal-accessory-command-row"
            setupRow(scrollView: navScrollView, stackView: navStackView, in: rowsStackView)

            for (scrollView, leadingFade, trailingFade) in [
                (navScrollView, navLeadingFade, navTrailingFade),
                (commandScrollView, commandLeadingFade, commandTrailingFade),
            ] {
                leadingFade.translatesAutoresizingMaskIntoConstraints = false
                trailingFade.translatesAutoresizingMaskIntoConstraints = false
                // Added after the rows so the fades draw above the buttons.
                blurView.contentView.addSubview(leadingFade)
                blurView.contentView.addSubview(trailingFade)
                NSLayoutConstraint.activate([
                    leadingFade.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                    leadingFade.topAnchor.constraint(equalTo: scrollView.topAnchor),
                    leadingFade.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                    leadingFade.widthAnchor.constraint(equalToConstant: 24),
                    trailingFade.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                    trailingFade.topAnchor.constraint(equalTo: scrollView.topAnchor),
                    trailingFade.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                    trailingFade.widthAnchor.constraint(equalToConstant: 24),
                ])
            }

            // Bottom-align with the nav row (nearest the keyboard) rather than
            // the whole two-row bar's center. navScrollView has no superview
            // until the setupRow() call above arranges it inside rowsStackView,
            // so this constraint must activate after that point or it has no
            // common ancestor with hideKeyboardButton to resolve against.
            NSLayoutConstraint.activate([
                hideKeyboardButton.centerYAnchor.constraint(equalTo: navScrollView.centerYAnchor),
            ])

            rebuildCommandRow()

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
            scrollView.delegate = self
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
                let button = makeAccessoryButton { [weak self] in
                    guard let terminalView = self?.eligibleTerminalView else { return }
                    terminalView.inputAccessoryActions.first { $0.id == action.id }?.handler()
                }
                button.accessibilityLabel = action.accessibilityLabel
                let imageName = action.isSelected
                    ? action.selectedSystemImage ?? action.systemImage
                    : action.systemImage
                button.setSystemImage(named: imageName)
                return button
            }
            customActionDivider.isHidden = isSlimForHardwareKeyboard || customActionButtons.isEmpty
            // Appended after the nav cluster (not inserted at index 0) —
            // see the ordering rationale in setupViews().
            for button in customActionButtons {
                navStackView.addArrangedSubview(button)
            }
        }

        private func toggleExtendedKeyMode() {
            showsExtendedKeys.toggle()
            rebuildCommandRow()
            commandScrollView.setContentOffset(.zero, animated: false)
            refreshContent()

            let firstRevealedControl = showsExtendedKeys ? shiftButton : interruptButton
            UIAccessibility.post(notification: .layoutChanged, argument: firstRevealedControl)
        }

        private func rebuildCommandRow() {
            for view in commandStackView.arrangedSubviews {
                commandStackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }

            let views: [UIView]
            if showsExtendedKeys {
                views = [
                    moreKeysButton,
                    shiftButton,
                    insertButton,
                    deleteForwardButton,
                ] + functionButtons
            } else {
                views = [
                    interruptButton,
                    escapeButton,
                    moreKeysButton,
                    ctrlButton,
                    altButton,
                    cmdButton,
                    commandDivider,
                    tabButton,
                    backtabButton,
                ] + symbolButtons + [
                    pasteControl,
                ]
            }
            addArrangedViews(views, to: commandStackView)
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
            let button = makeAccessoryButton { [weak self] in
                self?.eligibleTerminalView?.stickyModifiers.toggle(modifier)
            }
            button.accessibilityLabel = title
            button.setSystemImage(named: systemImage)
            return button
        }

        private func makeKeyButton(
            title: String,
            systemImage: String? = nil,
            accessibilityLabel: String? = nil,
            key: TerminalInputBarKey
        ) -> AccessoryButton {
            let button = makeAccessoryButton { [weak self] in
                self?.eligibleTerminalView?.handleInputBarKey(key)
            }
            button.accessibilityLabel = accessibilityLabel ?? title

            if let systemImage {
                button.setSystemImage(named: systemImage)
            } else {
                setTextTitle(title, on: button)
            }

            return button
        }

        private func setTextTitle(_ title: String, on button: AccessoryButton) {
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

        private func makeAccessoryButton(handler: @escaping () -> Void) -> AccessoryButton {
            AccessoryButton(
                width: buttonWidth,
                height: buttonHeight,
                handler: handler
            )
        }

        private var preferredHeight: CGFloat {
            Self.preferredHeight(for: isSlimForHardwareKeyboard ? Self.slimBarHeight : Self.barHeight)
        }

        private func applySlimMode() {
            commandScrollView.isHidden = isSlimForHardwareKeyboard
            for button in [
                homeButton, pageUpButton, leftButton, upButton,
                downButton, rightButton, pageDownButton, endButton,
            ] {
                button.isHidden = isSlimForHardwareKeyboard
            }
            customActionDivider.isHidden = isSlimForHardwareKeyboard || customActionButtons.isEmpty
            blurHeightConstraint?.constant = isSlimForHardwareKeyboard
                ? Self.slimBarHeight
                : Self.barHeight
            invalidateIntrinsicContentSize()
        }

        private func makePasteControl() -> UIPasteControl {
            let configuration = UIPasteControl.Configuration()
            configuration.displayMode = .iconOnly
            configuration.baseForegroundColor = style.regularForeground
            configuration.baseBackgroundColor = style.regularBackground
            configuration.cornerStyle = .fixed
            configuration.cornerRadius = 10
            let control = UIPasteControl(configuration: configuration)
            // No size constraints: UIPasteControl hides its glyph when
            // compressed below its designed size (a forced 32pt height
            // rendered it as a blank block). It self-sizes to fit the row.
            // The control stays dimmed and swallows taps unless its target
            // offers a pasteConfiguration accepting the pasteboard's types,
            // so the bar itself is the target and paste delivery arrives
            // through paste(itemProviders:) below.
            control.target = self
            return control
        }

        private let acceptedPasteConfiguration = UIPasteConfiguration(
            acceptableTypeIdentifiers: [UTType.plainText.identifier]
        )

        override public var pasteConfiguration: UIPasteConfiguration? {
            get { acceptedPasteConfiguration }
            // UIKit assigns nil when the control's target is torn down;
            // the accepted types never change, so writes are ignored.
            set {}
        }

        override public func paste(itemProviders _: [NSItemProvider]) {
            // This is the ONLY tap delivery path: once a UIPasteControl has
            // a target, UIKit routes the tap to the target's
            // paste(itemProviders:) and does not also fire
            // primaryActionTriggered (observed on iOS 27: an addTarget
            // handler alone left the enabled button dead). Wiring both would
            // double-paste on versions that fire the action as well. The tap
            // itself grants pasteboard access, so the handler's direct
            // pasteboard read never shows the system permission banner.
            eligibleTerminalView?.handlePasteFromPasteControl()
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            updateScrollFades()
        }

        private func updateScrollFades() {
            updateScrollFades(for: navScrollView, leading: navLeadingFade, trailing: navTrailingFade)
            updateScrollFades(for: commandScrollView, leading: commandLeadingFade, trailing: commandTrailingFade)
        }

        private func updateScrollFades(for scrollView: UIScrollView, leading: UIView, trailing: UIView) {
            let overflow = scrollView.contentSize.width - scrollView.bounds.width
            guard overflow > 1 else {
                leading.alpha = 0
                trailing.alpha = 0
                return
            }
            leading.alpha = scrollView.contentOffset.x > 1 ? 1 : 0
            trailing.alpha = scrollView.contentOffset.x < overflow - 1 ? 1 : 0
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
                // Cap at a single row's radius so the compact two-row glass
                // retains its toolbar shape rather than becoming a large pill.
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

        // Backtick is absent from iOS's stock keyboard entirely; tilde, pipe,
        // and backslash sit two taps deep on the 123→#+= symbol page. Every
        // other symbol key here is already one tap away, so those four are
        // the only additions worth surfacing on the bar.
        private static let symbols: [String] = ["`", "~", "|", "\\"]

        /// A horizontal gradient pinned to a row's edge, shown only while
        /// that edge has off-screen content. Non-interactive so taps fall
        /// through to the scroll view beneath.
        private final class EdgeFadeView: UIView {
            enum Edge { case leading, trailing }

            private let edge: Edge

            init(edge: Edge) {
                self.edge = edge
                super.init(frame: .zero)
                isUserInteractionEnabled = false
                alpha = 0
                updateColors()
            }

            @available(*, unavailable)
            required init?(coder _: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }

            override class var layerClass: AnyClass { CAGradientLayer.self }

            override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
                super.traitCollectionDidChange(previousTraitCollection)
                updateColors()
            }

            private func updateColors() {
                guard let gradient = layer as? CAGradientLayer else { return }
                // The bar is a dark-tinted material in every shipped
                // configuration, so fading toward black reads as the row
                // dissolving into the bar rather than a hard clip.
                let solid = UIColor.black.withAlphaComponent(0.45).cgColor
                let clear = UIColor.black.withAlphaComponent(0).cgColor
                gradient.colors = edge == .leading ? [solid, clear] : [clear, solid]
                gradient.startPoint = CGPoint(x: 0, y: 0.5)
                gradient.endPoint = CGPoint(x: 1, y: 0.5)
            }
        }
    }

    extension TerminalInputBar: UIScrollViewDelegate {
        public func scrollViewDidScroll(_: UIScrollView) {
            updateScrollFades()
        }
    }
#endif
