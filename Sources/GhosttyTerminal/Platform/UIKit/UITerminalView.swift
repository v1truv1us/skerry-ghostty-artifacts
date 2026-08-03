//
//  UITerminalView.swift
//  libghostty-spm
//
//  Created by Lakr233 on 2026/3/16.
//

#if canImport(UIKit)
    import GhosttyKit
    import UIKit

    public enum TerminalHorizontalSwipeDirection: Equatable, Sendable {
        case left
        case right
    }

    public enum TerminalTouchAction: Sendable {
        case horizontalSwipe(TerminalHorizontalSwipeDirection)
        /// Positive values reveal older history; negative values move toward live output.
        case verticalScroll(lines: Int)
    }

    public enum TerminalInputBarPresentationMode: Equatable, Sendable {
        case bundled
        case hostManaged
    }

    @MainActor
    public struct TerminalInputAccessoryAction {
        public let id: String
        public let accessibilityLabel: String
        public let systemImage: String
        public let selectedSystemImage: String?
        public let isSelected: Bool
        public let handler: () -> Void

        public init(
            id: String,
            accessibilityLabel: String,
            systemImage: String,
            selectedSystemImage: String? = nil,
            isSelected: Bool = false,
            handler: @escaping () -> Void
        ) {
            self.id = id
            self.accessibilityLabel = accessibilityLabel
            self.systemImage = systemImage
            self.selectedSystemImage = selectedSystemImage
            self.isSelected = isSelected
            self.handler = handler
        }
    }

    @MainActor
    public final class UITerminalView: UIView {
        let core = TerminalSurfaceCoordinator()
        var momentumDisplayLink: CADisplayLink?
        var momentumVelocity: CGPoint = .zero
        #if !targetEnvironment(macCatalyst)
            // Below 10 points the terminal becomes effectively unreadable on
            // an iPhone while still looking like a successfully loaded pane.
            // Keep interactive pinch/keyboard zoom aligned with the host's
            // persisted preference floor so an in-memory surface cannot drift
            // below the value the next launch accepts.
            static let minFontSize: Float = 10
            static let maxFontSize: Float = 64
        #endif
        // Tracks a pressed indirect-pointer (trackpad) button across the
        // touch phases so the release reports the same button. Used by
        // Catalyst's full pointer path and iPadOS's secondary-button path.
        var activePointerButton: ghostty_input_mouse_button_e?
        var hardwareKeyHandled = false
        let touchScrollMultiplier: CGFloat = 3.0
        var touchScrollLineRemainder: CGFloat = 0
        var touchScrollOwner = TerminalTouchScrollOwner.terminal
        var bufferedTouchScroll = CGPoint.zero
        var touchScrollContextTask: Task<Void, Never>?
        var touchScrollGestureGeneration = 0
        var pendingTouchScrollEndVelocity: CGPoint?
        var isTerminalSelectionActive = false
        var terminalSelectionModifiers = ghostty_input_mods_e(rawValue: 0)
        lazy var terminalEditMenuInteraction = UIEditMenuInteraction(delegate: self)
        // These points are snapshots of Ghostty's authoritative selected
        // range, never the touches that initiated or adjusted it. Keeping an
        // explicit ownership bit lets both offscreen endpoints disappear and
        // return after scrolling without mistaking invisibility for selection
        // cancellation.
        var ownsTerminalSelectionRange = false
        var selectionStartPoint: CGPoint?
        var selectionEndPoint: CGPoint?
        var selectionHandleDragTouchOffset: CGPoint?
        // Match UIKit's normal long-press intent threshold. The previous
        // 0.35-second/28-point combination classified an ordinary deliberate
        // one-finger drag as selection before scrolling could begin.
        static let selectionMinimumPressDuration: TimeInterval = 0.5
        static let selectionAllowableMovement: CGFloat = 10
        lazy var terminalSelectionGestureRecognizer: UILongPressGestureRecognizer = {
            let gesture = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleTerminalSelectionGesture(_:))
            )
            gesture.minimumPressDuration = Self.selectionMinimumPressDuration
            gesture.allowableMovement = Self.selectionAllowableMovement
            return gesture
        }()
        lazy var terminalScrollGestureRecognizer: UIPanGestureRecognizer = {
            let gesture = UIPanGestureRecognizer(
                target: self,
                action: #selector(handleTouchScrollGesture(_:))
            )
            gesture.minimumNumberOfTouches = 1
            gesture.maximumNumberOfTouches = 1
            return gesture
        }()
        lazy var startSelectionHandle = TerminalSelectionHandleView(edge: .start)
        lazy var endSelectionHandle = TerminalSelectionHandleView(edge: .end)
        #if !targetEnvironment(macCatalyst)
            var currentFontSize: Float = 12
            var lastPinchScale: CGFloat = 1.0
            var pinchChangedFontSize = false
            public var terminalFontSizeDidChange: ((Float) -> Void)?
        #endif
        lazy var inputHandler = TerminalTextInputHandler(view: self)
        weak var _inputDelegate: (any UITextInputDelegate)?

        #if !targetEnvironment(macCatalyst)
            lazy var terminalInputAccessory = TerminalInputBar(terminalView: self)
            let stickyModifiers = TerminalStickyModifierState()
            public var inputBarPresentationMode = TerminalInputBarPresentationMode.bundled {
                didSet {
                    guard inputBarPresentationMode != oldValue else { return }
                    reloadInputViews()
                }
            }
        #endif

        public var isResponderEligible = false {
            didSet {
                guard !isResponderEligible else { return }
                resignFirstResponder()
            }
        }

        /// VoiceOver sees the terminal as one direct-interaction element:
        /// focusable, and touches pass straight through for typing. Terminal
        /// content itself is never exposed to assistive technology — the
        /// raw-bytes invariant forbids decoding the PTY, so the label stays
        /// content-free. Hosts may relabel it (e.g. per-pane context).
        public var terminalAccessibilityLabel = "Terminal" {
            didSet { accessibilityLabel = terminalAccessibilityLabel }
        }

        #if !targetEnvironment(macCatalyst)
            public var inputAccessoryStyle: TerminalInputAccessoryStyle {
                get { terminalInputAccessory.style }
                set { terminalInputAccessory.style = newValue }
            }
        #endif

        public weak var delegate: (any TerminalSurfaceViewDelegate)? {
            get { core.delegate }
            set { core.delegate = newValue }
        }

        /// When set, Skerry owns terminal touch navigation (for example, tmux window
        /// switching and copy-mode history). Returning false preserves Ghostty input.
        public var touchActionHandler: ((TerminalTouchAction) -> Bool)?

        /// The host has independently confirmed that the active remote pane is
        /// using an alternate screen without mouse reporting. Ghostty maps a
        /// wheel to cursor keys in that state, so a host scrollback provider may
        /// take one-finger vertical scrolling. Never infer this from mouse
        /// capture alone: primary-screen scrollback must remain Ghostty-owned.
        public var isUncapturedAlternateScreen = false

        /// Called after Ghostty completes a rendered frame. The callback must
        /// never inspect or receive terminal content.
        public var postRenderHandler: (() -> Void)?

        /// Resolves the content-free destination for this exact gesture.
        /// UITerminalView buffers vertical movement while awaiting the result,
        /// because a fire-and-forget refresh followed by a synchronous routing
        /// decision necessarily reads stale state. Nil means the host could
        /// not prove current context, so the gesture is discarded rather than
        /// converted into cursor-key input.
        public var touchScrollContextProvider: (@MainActor () async -> TerminalTouchScrollDestination?)?

        public var inputAccessoryActions: [TerminalInputAccessoryAction] = [] {
            didSet {
                refreshInputAccessoryContent()
                hostInputBarContentDidChange?()
            }
        }
        var hostInputBarContentDidChange: (() -> Void)?

        public var controller: TerminalController? {
            get { core.controller }
            set {
                core.controller = newValue
                // A freshly created controller defaults to `.light` and only
                // learns the real system appearance via `updateColorScheme()`,
                // which normally runs from `didMoveToWindow()`. That won't
                // fire again for a view that's already attached to a window
                // when its controller is swapped out from under it (e.g. a
                // host app replacing the controller after a reconnect), so
                // the new controller would otherwise stay stuck on `.light`.
                if window != nil {
                    updateColorScheme()
                }
            }
        }

        public var configuration: TerminalSurfaceOptions {
            get { core.configuration }
            set { core.configuration = newValue }
        }

        var surface: TerminalSurface? {
            core.surface
        }

        public var hasText: Bool {
            true
        }

        override public var canBecomeFirstResponder: Bool {
            isResponderEligible
        }

        override public init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func commonInit() {
            backgroundColor = .clear
            isOpaque = false
            isUserInteractionEnabled = true
            isAccessibilityElement = true
            accessibilityLabel = terminalAccessibilityLabel
            accessibilityTraits = [.allowsDirectInteraction]
            updateDisplayScale()

            core.isAttached = { [weak self] in self?.window != nil }
            core.scaleFactor = { [weak self] in
                Double(self?.resolvedDisplayScale() ?? UIScreen.main.nativeScale)
            }
            core.viewSize = { [weak self] in
                guard let self else { return (0, 0) }
                return (bounds.width, bounds.height)
            }
            core.platformSetup = { [weak self] config in
                guard let self else { return }
                config.platform_tag = GHOSTTY_PLATFORM_IOS
                config.platform = ghostty_platform_u(
                    ios: ghostty_platform_ios_s(
                        uiview: Unmanaged.passUnretained(self).toOpaque()
                    )
                )
            }
            core.onMetricsUpdate = { [weak self] in
                self?.updateSublayerFrames()
            }
            core.onCellSizeDidChange = { [weak self] in
                self?.refreshTextInputGeometry(reason: "cell-size-action")
            }
            core.onPostRender = { [weak self] in
                self?.enforceSublayerScale()
                self?.synchronizeSelectionHandlesWithSurface()
                self?.postRenderHandler?()
            }

            setupPlatformInput()
            setupSelectionHandles()
        }

        func refreshTextInputGeometry(reason: String) {
            guard isFirstResponder || inputHandler.hasMarkedText else { return }
            TerminalDebugLog.log(.ime, "refresh text geometry reason=\(reason)")
            inputHandler.notifyGeometryDidChange(reason: reason)
        }

        func refreshInputAccessoryContent() {
            #if !targetEnvironment(macCatalyst)
                terminalInputAccessory.refreshContent()
            #endif
        }
    }

    extension UITerminalView: UIGestureRecognizerDelegate {
        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
                || (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
        }
    }
#endif
