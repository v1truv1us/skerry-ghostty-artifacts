//
//  UITerminalView+Interaction.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/17.
//

#if canImport(UIKit)
    import GhosttyKit
    import UIKit

    extension UITerminalView {
        override public func touchesBegan(
            _ touches: Set<UITouch>,
            with event: UIEvent?
        ) {
            #if targetEnvironment(macCatalyst)
                if handleIndirectPointerTouches(touches, phase: .began, event: event) {
                    return
                }
            #endif
            super.touchesBegan(touches, with: event)
        }

        override public func touchesMoved(
            _ touches: Set<UITouch>,
            with event: UIEvent?
        ) {
            #if targetEnvironment(macCatalyst)
                if handleIndirectPointerTouches(touches, phase: .moved, event: event) {
                    return
                }
            #endif
            super.touchesMoved(touches, with: event)
        }

        override public func touchesEnded(
            _ touches: Set<UITouch>,
            with event: UIEvent?
        ) {
            #if targetEnvironment(macCatalyst)
                if handleIndirectPointerTouches(touches, phase: .ended, event: event) {
                    return
                }
            #endif
            super.touchesEnded(touches, with: event)
        }

        override public func touchesCancelled(
            _ touches: Set<UITouch>,
            with event: UIEvent?
        ) {
            #if targetEnvironment(macCatalyst)
                if handleIndirectPointerTouches(touches, phase: .cancelled, event: event) {
                    return
                }
            #endif
            super.touchesCancelled(touches, with: event)
        }

        func setupPlatformInput() {
            #if targetEnvironment(macCatalyst)
                setupCatalystScrollWheelInput()
            #else
                setupTouchScrollInput()
            #endif
        }

        #if targetEnvironment(macCatalyst)
            func setupCatalystScrollWheelInput() {
                let gesture = UIPanGestureRecognizer(
                    target: self,
                    action: #selector(handleCatalystScrollWheelGesture(_:))
                )
                gesture.allowedScrollTypesMask = [.continuous, .discrete]
                gesture.cancelsTouchesInView = false
                gesture.delaysTouchesBegan = false
                gesture.delaysTouchesEnded = false
                addGestureRecognizer(gesture)
            }

            @objc func handleCatalystScrollWheelGesture(
                _ gesture: UIPanGestureRecognizer
            ) {
                guard activePointerButton == nil else { return }

                let translation = gesture.translation(in: self)
                gesture.setTranslation(.zero, in: self)
                TerminalDebugLog.log(
                    .input,
                    "catalyst scroll translation=\(String(format: "%.2f", translation.x))x\(String(format: "%.2f", translation.y))"
                )

                let scrollMods = TerminalScrollModifiers(precision: true)
                surface?.sendMouseScroll(
                    x: Double(translation.x),
                    y: Double(translation.y),
                    mods: scrollMods.rawValue
                )
            }

            enum IndirectPointerPhase {
                case began
                case moved
                case ended
                case cancelled
            }

            func handleIndirectPointerTouches(
                _ touches: Set<UITouch>,
                phase: IndirectPointerPhase,
                event: UIEvent?
            ) -> Bool {
                guard let touch = touches.first(where: { $0.type == .indirectPointer }) else {
                    return false
                }

                stopMomentumScrolling()

                let button = pointerButton(from: event)
                let mods = ghostty_input_mods_e(rawValue: 0)
                let location = touch.location(in: self)
                surface?.sendMousePos(
                    x: location.x,
                    y: location.y,
                    mods: mods
                )

                switch phase {
                case .began:
                    activePointerButton = button
                    surface?.sendMouseButton(
                        state: GHOSTTY_MOUSE_PRESS,
                        button: button,
                        mods: mods
                    )

                case .moved:
                    break

                case .ended, .cancelled:
                    let releasedButton = activePointerButton ?? button
                    activePointerButton = nil
                    surface?.sendMouseButton(
                        state: GHOSTTY_MOUSE_RELEASE,
                        button: releasedButton,
                        mods: mods
                    )
                }

                return true
            }

            func pointerButton(from event: UIEvent?) -> ghostty_input_mouse_button_e {
                guard let event else { return GHOSTTY_MOUSE_LEFT }
                if event.buttonMask.contains(.secondary) {
                    return GHOSTTY_MOUSE_RIGHT
                }
                if event.buttonMask.contains(.primary) {
                    return GHOSTTY_MOUSE_LEFT
                }
                return GHOSTTY_MOUSE_LEFT
            }
        #else
            func setupTouchScrollInput() {
                addGestureRecognizer(terminalSelectionGestureRecognizer)

                let tapGesture = UITapGestureRecognizer(
                    target: self,
                    action: #selector(handleTerminalTapGesture(_:))
                )
                tapGesture.require(toFail: terminalSelectionGestureRecognizer)
                addGestureRecognizer(tapGesture)

                addGestureRecognizer(terminalScrollGestureRecognizer)
                tapGesture.require(toFail: terminalScrollGestureRecognizer)

                let windowSwipeGesture = UIPanGestureRecognizer(
                    target: self,
                    action: #selector(handleTerminalWindowSwipeGesture(_:))
                )
                windowSwipeGesture.minimumNumberOfTouches = 2
                windowSwipeGesture.maximumNumberOfTouches = 2
                addGestureRecognizer(windowSwipeGesture)

                addInteraction(terminalEditMenuInteraction)

                currentFontSize = Self.validatedFontSize(configuration.fontSize ?? 12)
                setupPinchZoomGesture()
            }
        #endif

        @objc func handleTerminalTapGesture(_ gesture: UITapGestureRecognizer) {
            handleTerminalTap(
                state: gesture.state,
                location: gesture.location(in: self)
            )
        }

        func handleTerminalTap(
            state: UIGestureRecognizer.State,
            location: CGPoint
        ) {
            guard state == .ended else { return }
            guard canBecomeFirstResponder else { return }
            becomeFirstResponder()
            hideSelectionHandles()
            guard let surface else { return }
            // Ghostty intentionally activates recognized links with Command-click
            // on Apple platforms. A direct touch has no hardware modifier, so it
            // must emulate Command for URL activation to be reachable on iPhone
            // and iPad. Non-link mouse events continue through Ghostty normally.
            let mods = TerminalInputModifiers.linkActivation(
                isMouseCaptured: surface.isMouseCaptured
            ).ghosttyMods
            surface.sendMousePos(x: location.x, y: location.y, mods: mods)
            surface.sendMouseButton(
                state: GHOSTTY_MOUSE_PRESS,
                button: GHOSTTY_MOUSE_LEFT,
                mods: mods
            )
            surface.sendMouseButton(
                state: GHOSTTY_MOUSE_RELEASE,
                button: GHOSTTY_MOUSE_LEFT,
                mods: mods
            )
        }

        @objc func handleTerminalSelectionGesture(_ gesture: UILongPressGestureRecognizer) {
            guard let surface else { return }
            let location = gesture.location(in: self)

            switch gesture.state {
            case .began:
                stopMomentumScrolling()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                hideSelectionHandles()
                terminalSelectionModifiers = surface.isMouseCaptured
                    ? TerminalInputModifiers.shift.ghosttyMods
                    : ghostty_input_mods_e(rawValue: 0)
                isTerminalSelectionActive = true
                selectionStartPoint = location
                surface.sendMousePos(
                    x: location.x,
                    y: location.y,
                    mods: terminalSelectionModifiers
                )
                surface.sendMouseButton(
                    state: GHOSTTY_MOUSE_PRESS,
                    button: GHOSTTY_MOUSE_LEFT,
                    mods: terminalSelectionModifiers
                )

            case .changed:
                guard isTerminalSelectionActive else { return }
                selectionEndPoint = location
                surface.sendMousePos(
                    x: location.x,
                    y: location.y,
                    mods: terminalSelectionModifiers
                )

            case .ended:
                guard isTerminalSelectionActive else { return }
                selectionEndPoint = location
                finishTerminalSelection(at: location, showMenu: true)

            case .cancelled, .failed:
                guard isTerminalSelectionActive else { return }
                finishTerminalSelection(at: location, showMenu: false)

            default:
                break
            }
        }

        private func finishTerminalSelection(at location: CGPoint, showMenu: Bool) {
            guard let surface else { return }
            surface.sendMousePos(
                x: location.x,
                y: location.y,
                mods: terminalSelectionModifiers
            )
            surface.sendMouseButton(
                state: GHOSTTY_MOUSE_RELEASE,
                button: GHOSTTY_MOUSE_LEFT,
                mods: terminalSelectionModifiers
            )
            isTerminalSelectionActive = false

            guard showMenu, let start = selectionStartPoint else {
                hideSelectionHandles()
                return
            }
            showSelectionHandles(start: start, end: location)
            presentSelectionEditMenu(at: location)
        }

        @objc func handleTouchScrollGesture(
            _ gesture: UIPanGestureRecognizer
        ) {
            switch gesture.state {
            case .began:
                TerminalDebugLog.log(.input, "touch scroll began")
                scrollGestureWillBeginHandler?()
                stopMomentumScrolling()
                hideSelectionHandles()
                tmuxScrollRemainder = 0
                bufferedTouchScroll = .zero
                touchScrollOwner = TerminalTouchScrollRouting.initialOwner(
                    isMouseCaptured: surface?.isMouseCaptured == true,
                    hasHostHandler: touchActionHandler != nil,
                    isUncapturedAlternateScreen: isUncapturedAlternateScreen
                )

            case .changed:
                let translation = gesture.translation(in: self)
                gesture.setTranslation(.zero, in: self)
                TerminalDebugLog.log(
                    .input,
                    "touch scroll changed translation=\(String(format: "%.2f", translation.x))x\(String(format: "%.2f", translation.y))"
                )

                if touchScrollOwner == .terminal {
                    sendTerminalScroll(translation)
                } else if let touchActionHandler, abs(translation.y) >= abs(translation.x) {
                    bufferedTouchScroll.x += translation.x
                    bufferedTouchScroll.y += translation.y
                    tmuxScrollRemainder += translation.y
                    let rowCount = max(CGFloat(surface?.size()?.rows ?? 24), 1)
                    let lineHeight = max(bounds.height / rowCount, 1)
                    let lines = Int(tmuxScrollRemainder / lineHeight)
                    if lines != 0 {
                        if touchActionHandler(.verticalScroll(lines: lines)) {
                            touchScrollOwner = .host
                            tmuxScrollRemainder -= CGFloat(lines) * lineHeight
                            bufferedTouchScroll = .zero
                        } else {
                            touchScrollOwner = .terminal
                            sendTerminalScroll(bufferedTouchScroll)
                            bufferedTouchScroll = .zero
                            tmuxScrollRemainder = 0
                        }
                    }
                } else {
                    touchScrollOwner = .terminal
                    sendTerminalScroll(translation)
                }

            case .ended:
                let velocity = gesture.velocity(in: self)
                TerminalDebugLog.log(
                    .input,
                    "touch scroll ended velocity=\(String(format: "%.2f", velocity.x))x\(String(format: "%.2f", velocity.y))"
                )
                if touchScrollOwner == .host, let touchActionHandler {
                    let velocityLines = max(-12, min(12, Int(velocity.y / 320)))
                    if velocityLines != 0 {
                        if !touchActionHandler(.verticalScroll(lines: velocityLines)) {
                            startMomentumScrolling(velocity: velocity)
                        }
                    }
                } else {
                    if touchScrollOwner == .undecided, bufferedTouchScroll != .zero {
                        sendTerminalScroll(bufferedTouchScroll)
                    }
                    startMomentumScrolling(velocity: velocity)
                }
                tmuxScrollRemainder = 0
                bufferedTouchScroll = .zero

            case .cancelled, .failed:
                TerminalDebugLog.log(.input, "touch scroll cancelled")
                stopMomentumScrolling()
                tmuxScrollRemainder = 0
                bufferedTouchScroll = .zero

            default:
                break
            }
        }

        private func sendTerminalScroll(_ translation: CGPoint) {
            let scrollMods = TerminalScrollModifiers(precision: true)
            surface?.sendMouseScroll(
                x: Double(translation.x * touchScrollMultiplier),
                y: Double(translation.y * touchScrollMultiplier),
                mods: scrollMods.rawValue
            )
        }

        @objc func handleTerminalWindowSwipeGesture(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .ended, let touchActionHandler else { return }
            guard !pinchChangedFontSize else { return }
            let translation = gesture.translation(in: self)
            let velocity = gesture.velocity(in: self)
            guard abs(translation.x) >= 44,
                  abs(translation.x) > abs(translation.y),
                  abs(velocity.x) > abs(velocity.y)
            else { return }

            let direction: TerminalHorizontalSwipeDirection = translation.x < 0 ? .left : .right
            _ = touchActionHandler(.horizontalSwipe(direction))
        }

        func startMomentumScrolling(velocity: CGPoint) {
            guard abs(velocity.x) > 50 || abs(velocity.y) > 50 else { return }

            momentumVelocity = velocity
            TerminalDebugLog.log(
                .input,
                "momentum start velocity=\(String(format: "%.2f", velocity.x))x\(String(format: "%.2f", velocity.y))"
            )

            let mods = TerminalScrollModifiers(precision: true, momentum: .began)
            surface?.sendMouseScroll(x: 0, y: 0, mods: mods.rawValue)

            let link = CADisplayLink(
                target: self,
                selector: #selector(momentumScrollFrame(_:))
            )
            link.add(to: .main, forMode: .common)
            momentumDisplayLink = link
        }

        @objc func momentumScrollFrame(_ link: CADisplayLink) {
            let dt = link.targetTimestamp - link.timestamp
            let deceleration: CGFloat = 0.92

            momentumVelocity.x *= deceleration
            momentumVelocity.y *= deceleration

            let deltaX = momentumVelocity.x * dt * touchScrollMultiplier
            let deltaY = momentumVelocity.y * dt * touchScrollMultiplier

            if abs(momentumVelocity.x) < 50, abs(momentumVelocity.y) < 50 {
                stopMomentumScrolling()
                return
            }

            TerminalDebugLog.log(
                .input,
                "momentum frame velocity=\(String(format: "%.2f", momentumVelocity.x))x\(String(format: "%.2f", momentumVelocity.y)) delta=\(String(format: "%.2f", deltaX))x\(String(format: "%.2f", deltaY))"
            )

            let mods = TerminalScrollModifiers(precision: true, momentum: .changed)
            surface?.sendMouseScroll(
                x: Double(deltaX),
                y: Double(deltaY),
                mods: mods.rawValue
            )
        }

        func stopMomentumScrolling() {
            guard momentumDisplayLink != nil else { return }
            TerminalDebugLog.log(.input, "momentum stop")

            let mods = TerminalScrollModifiers(precision: true, momentum: .none)
            surface?.sendMouseScroll(x: 0, y: 0, mods: mods.rawValue)

            momentumDisplayLink?.invalidate()
            momentumDisplayLink = nil
            momentumVelocity = .zero
        }
    }

    extension UITerminalView: @MainActor UIEditMenuInteractionDelegate {
        public func editMenuInteraction(
            _: UIEditMenuInteraction,
            menuFor _: UIEditMenuConfiguration,
            suggestedActions _: [UIMenuElement]
        ) -> UIMenu? {
            var children: [UIMenuElement] = [
                UIAction(
                    title: "Copy",
                    image: UIImage(systemName: "doc.on.doc")
                ) { [weak self] _ in
                    _ = self?.surface?.performBindingAction("copy_to_clipboard")
                },
                UIAction(
                    title: "Select All",
                    image: UIImage(systemName: "selection.pin.in.out")
                ) { [weak self] _ in
                    _ = self?.surface?.performBindingAction("select_all")
                },
            ]

            // `hasStrings` is a non-consuming check: it does not read the
            // pasteboard contents, so it never triggers the iOS paste banner
            // just to decide whether to offer Paste.
            if UIPasteboard.general.hasStrings {
                children.append(
                    UIAction(
                        title: "Paste",
                        image: UIImage(systemName: "doc.on.clipboard")
                    ) { [weak self] _ in
                        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
                        self?.inputHandler.pasteText(text)
                    }
                )
            }

            return UIMenu(children: children)
        }
    }
#endif
