#if canImport(UIKit) && !targetEnvironment(macCatalyst)
import GhosttyKit
import UIKit
import XCTest
@testable import GhosttyTerminal

@MainActor
final class UITerminalInspectionTests: XCTestCase {
    func testResponderEligibilityGatesAndImmediatelyResignsFocus() {
        let terminal = UITerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let controller = UIViewController()
        controller.view = terminal
        let window = UIWindow(frame: terminal.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        XCTAssertFalse(terminal.canBecomeFirstResponder)
        terminal.isResponderEligible = true
        XCTAssertTrue(terminal.becomeFirstResponder())
        XCTAssertTrue(terminal.isFirstResponder)

        terminal.isResponderEligible = false
        XCTAssertFalse(terminal.isFirstResponder)
        XCTAssertFalse(terminal.canBecomeFirstResponder)
    }

    /// Rotation changes the terminal bounds without producing PTY output. A
    /// layout resize must actually resynchronize Ghostty's grid to the new
    /// bounds and schedule a render of that resized state — not merely
    /// produce *some* rendered frame, which the demand-tick pump can fire
    /// even when synchronizeMetrics() no-ops against a missing surface. This
    /// attaches a real controller + in-memory surface so the grid-size
    /// assertion actually exercises the resize path, not just tick delivery.
    func testLayoutResizeSchedulesAFrameWithoutTerminalOutput() async throws {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        let terminal = UITerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        terminal.controller = TerminalController()
        terminal.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        let controller = UIViewController()
        controller.view = terminal
        let window = UIWindow(frame: terminal.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // Drain attachment/layout work before observing the rotation-sized
        // layout independently.
        await Task.yield()
        await Task.yield()

        let surface = try XCTUnwrap(terminal.surface, "expected a live surface for a windowed, configured terminal")
        let initialSize = try XCTUnwrap(surface.size())

        var renderedFrameCount = 0
        terminal.postRenderHandler = { renderedFrameCount += 1 }

        terminal.frame = CGRect(x: 0, y: 0, width: 480, height: 320)
        terminal.setNeedsLayout()
        terminal.layoutIfNeeded()
        await Task.yield()
        await Task.yield()

        XCTAssertGreaterThan(renderedFrameCount, 0)
        let resizedSize = try XCTUnwrap(surface.size())
        XCTAssertNotEqual(
            resizedSize.columns,
            initialSize.columns,
            "rotation must resynchronize the grid to the new bounds, not just fire an unrelated tick"
        )
    }

    func testHostManagedInputBarRetargetsWeaklyAndSuppressesBundledAccessory() {
        var firstTerminal: UITerminalView? = UITerminalView(frame: .zero)
        let secondTerminal = UITerminalView(frame: .zero)
        let inputBar = TerminalInputBar(terminalView: firstTerminal)

        firstTerminal?.inputBarPresentationMode = .hostManaged
        XCTAssertNil(firstTerminal?.inputAccessoryView)
        XCTAssertTrue(inputBar.terminalView === firstTerminal)

        inputBar.setTerminalView(secondTerminal)
        XCTAssertTrue(inputBar.terminalView === secondTerminal)
        firstTerminal = nil
        XCTAssertTrue(inputBar.terminalView === secondTerminal)

        inputBar.setTerminalView(nil)
        XCTAssertNil(inputBar.terminalView)
    }

    func testHostManagedInputBarRoutesActionsAndStickyModifiersOnlyToCurrentTarget() throws {
        let firstTerminal = UITerminalView(frame: .zero)
        let secondTerminal = UITerminalView(frame: .zero)
        firstTerminal.isResponderEligible = true
        var firstActionCount = 0
        var secondActionCount = 0
        firstTerminal.inputAccessoryActions = [testAction(id: "first") { firstActionCount += 1 }]
        secondTerminal.inputAccessoryActions = [testAction(id: "second") { secondActionCount += 1 }]
        let inputBar = TerminalInputBar(terminalView: firstTerminal)

        try tapButton(label: "Action first", in: inputBar)
        try tapButton(label: "Control", in: inputBar)
        XCTAssertEqual(firstActionCount, 1)
        XCTAssertEqual(secondActionCount, 0)
        XCTAssertEqual(firstTerminal.stickyActivation(for: .ctrl), .armed)
        XCTAssertEqual(secondTerminal.stickyActivation(for: .ctrl), .inactive)

        firstTerminal.isResponderEligible = false
        secondTerminal.isResponderEligible = true
        inputBar.setTerminalView(secondTerminal)
        try tapButton(label: "Action second", in: inputBar)
        try tapButton(label: "Control", in: inputBar)
        XCTAssertEqual(firstActionCount, 1)
        XCTAssertEqual(secondActionCount, 1)
        XCTAssertEqual(firstTerminal.stickyActivation(for: .ctrl), .armed)
        XCTAssertEqual(secondTerminal.stickyActivation(for: .ctrl), .armed)

        secondTerminal.inputAccessoryActions = [testAction(id: "updated") { secondActionCount += 10 }]
        try tapButton(label: "Action updated", in: inputBar)
        XCTAssertEqual(secondActionCount, 11)
    }

    /// The host-managed accessory bar remains usable while UIKit is rebuilding
    /// the render surface during a tab or foreground transition. Unmodified
    /// Tab is raw terminal input and does not depend on a Ghostty surface.
    func testHostManagedTabSendsRawByteWithoutRenderedSurface() throws {
        let recorder = TerminalInputRecorder()
        let session = InMemoryTerminalSession(
            write: { recorder.append($0) },
            resize: { _ in }
        )
        let terminal = UITerminalView(frame: .zero)
        terminal.configuration = TerminalSurfaceOptions(
            backend: .inMemory(session)
        )
        terminal.isResponderEligible = true
        let inputBar = TerminalInputBar(terminalView: terminal)

        try tapButton(label: "Tab", in: inputBar)

        XCTAssertEqual(recorder.data, Data([0x09]))
    }

    /// The bundled accessory bar's symbol row was empty until now. Backtick
    /// is absent from iOS's stock keyboard entirely; tilde, pipe, and
    /// backslash sit two taps deep on the 123→#+= page. Confirms every
    /// intended symbol renders a findable button and dispatches its raw byte,
    /// mirroring testHostManagedTabSendsRawByteWithoutRenderedSurface's proof
    /// that accessory input works without a rendered Ghostty surface.
    func testHostManagedSymbolButtonsSendRawBytesWithoutRenderedSurface() throws {
        let recorder = TerminalInputRecorder()
        let session = InMemoryTerminalSession(
            write: { recorder.append($0) },
            resize: { _ in }
        )
        let terminal = UITerminalView(frame: .zero)
        terminal.configuration = TerminalSurfaceOptions(
            backend: .inMemory(session)
        )
        terminal.isResponderEligible = true
        let inputBar = TerminalInputBar(terminalView: terminal)

        for label in ["`", "~", "|", "\\"] {
            try tapButton(label: label, in: inputBar)
        }

        XCTAssertEqual(recorder.data, Data([0x60, 0x7E, 0x7C, 0x5C]))
    }

    /// iOS's software keyboard has no Insert, forward Delete, or function
    /// keys. They must be reachable without growing the compact two-row bar
    /// back over the terminal viewport.
    func testMoreKeysModeExposesExtendedKeysWithoutGrowingActionBar() throws {
        let inputBar = TerminalInputBar()
        let initialHeight = inputBar.intrinsicContentSize.height

        XCTAssertNil(findButton(label: "Shift", in: inputBar))
        try tapButton(label: "More Keys", in: inputBar)

        for label in ["Shift", "Insert", "Forward Delete"] + (1 ... 12).map({ "F\($0)" }) {
            XCTAssertNotNil(findButton(label: label, in: inputBar), "Missing \(label)")
        }
        XCTAssertEqual(inputBar.intrinsicContentSize.height, initialHeight, accuracy: 0.5)
        XCTAssertEqual(findButton(label: "More Keys", in: inputBar)?.accessibilityValue, "Expanded")

        try tapButton(label: "More Keys", in: inputBar)
        XCTAssertNotNil(findButton(label: "Interrupt (Control-C)", in: inputBar))
        XCTAssertNil(findButton(label: "F1", in: inputBar))
        XCTAssertEqual(findButton(label: "More Keys", in: inputBar)?.accessibilityValue, "Collapsed")
    }

    func testExtendedAccessoryKeysSendRawBytesWithoutRenderedSurface() throws {
        let recorder = TerminalInputRecorder()
        let session = InMemoryTerminalSession(
            write: { recorder.append($0) },
            resize: { _ in }
        )
        let terminal = UITerminalView(frame: .zero)
        terminal.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        terminal.isResponderEligible = true
        let inputBar = TerminalInputBar(terminalView: terminal)

        try tapButton(label: "More Keys", in: inputBar)
        try tapButton(label: "Insert", in: inputBar)
        try tapButton(label: "Forward Delete", in: inputBar)
        for number in 1 ... 12 {
            try tapButton(label: "F\(number)", in: inputBar)
        }

        let expected = "\u{1B}[2~\u{1B}[3~"
            + "\u{1B}OP\u{1B}OQ\u{1B}OR\u{1B}OS"
            + "\u{1B}[15~\u{1B}[17~\u{1B}[18~\u{1B}[19~"
            + "\u{1B}[20~\u{1B}[21~\u{1B}[23~\u{1B}[24~"
        XCTAssertEqual(recorder.data, Data(expected.utf8))
    }

    /// Switching back to the command row must not consume one-shot Shift;
    /// otherwise Backtab remains inaccessible even after exposing Shift.
    func testShiftSurvivesMoreKeysToggleAndSendsBacktabWithoutRenderedSurface() throws {
        let recorder = TerminalInputRecorder()
        let session = InMemoryTerminalSession(
            write: { recorder.append($0) },
            resize: { _ in }
        )
        let terminal = UITerminalView(frame: .zero)
        terminal.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        terminal.isResponderEligible = true
        let inputBar = TerminalInputBar(terminalView: terminal)

        try tapButton(label: "More Keys", in: inputBar)
        try tapButton(label: "Shift", in: inputBar)
        try tapButton(label: "More Keys", in: inputBar)
        try tapButton(label: "Tab", in: inputBar)

        XCTAssertEqual(recorder.data, Data("\u{1B}[Z".utf8))
        XCTAssertEqual(terminal.stickyActivation(for: .shift), .inactive)
    }

    func testHostManagedInputBarRejectsCommandsForAnIneligibleTarget() throws {
        let terminal = UITerminalView(frame: .zero)
        var actionCount = 0
        terminal.inputAccessoryActions = [testAction(id: "stale") { actionCount += 1 }]
        let inputBar = TerminalInputBar(terminalView: terminal)

        try tapButton(label: "Action stale", in: inputBar)
        try tapButton(label: "Control", in: inputBar)

        XCTAssertEqual(actionCount, 0)
        XCTAssertEqual(terminal.stickyActivation(for: .ctrl), .inactive)
    }

    /// Command-then-tap would otherwise be an invisible interaction to
    /// VoiceOver users because the accessory is rendered as a symbol only.
    func testCommandAccessoryExplainsCapturedTerminalLinkActivation() throws {
        let inputBar = TerminalInputBar()
        let commandButton = try XCTUnwrap(findButton(label: "Command", in: inputBar))

        XCTAssertEqual(
            commandButton.accessibilityHint,
            "Tap once, then tap a terminal link to open it. Double-tap to lock Command."
        )
    }

    /// The circular two-row controls consumed too much of the already-small
    /// phone terminal. Keep their 44-point width, shorten the visual control,
    /// and use filled arrowheads so Up cannot be mistaken for the outlined
    /// Control symbol while the compact bar remains legible.
    func testActionBarUsesShortRectangularButtonsAndFilledArrowheads() throws {
        let inputBar = TerminalInputBar()
        inputBar.frame = CGRect(
            origin: .zero,
            size: CGSize(width: 390, height: inputBar.intrinsicContentSize.height)
        )
        inputBar.layoutIfNeeded()

        let control = try XCTUnwrap(
            findButton(label: "Control", in: inputBar) as? AccessoryButton
        )
        XCTAssertEqual(control.bounds.width, 44, accuracy: 0.5)
        XCTAssertEqual(control.bounds.height, 32, accuracy: 0.5)
        XCTAssertLessThan(control.bounds.height, control.bounds.width)
        XCTAssertEqual(control.layer.cornerRadius, 10, accuracy: 0.5)

        let expectedArrowheads = [
            "Left": "arrowtriangle.left.fill",
            "Up": "arrowtriangle.up.fill",
            "Down": "arrowtriangle.down.fill",
            "Right": "arrowtriangle.right.fill",
        ]
        for (label, imageName) in expectedArrowheads {
            let button = try XCTUnwrap(
                findButton(label: label, in: inputBar) as? AccessoryButton
            )
            XCTAssertEqual(button.systemImageName, imageName)
        }

        let glassView = try XCTUnwrap(
            inputBar.subviews.compactMap { $0 as? UIVisualEffectView }.first
        )
        XCTAssertEqual(glassView.bounds.height, 80, accuracy: 0.5)
    }

    /// Command-then-tap is the explicit local-link path inside a
    /// mouse-capturing TUI. One-shot Command must clear after that tap while
    /// unrelated modifiers remain armed; locked Command intentionally persists.
    func testPointerLinkActivationConsumesOnlyOneShotCommandModifier() {
        let modifiers = TerminalStickyModifierState()
        modifiers.toggle(.ctrl)
        modifiers.toggle(.command)

        XCTAssertTrue(modifiers.consumeCommandForPointerLinkActivation())
        XCTAssertTrue(modifiers.command == .inactive)
        XCTAssertTrue(modifiers.ctrl == .armed)

        modifiers.toggle(.command)
        modifiers.toggle(.command)
        XCTAssertTrue(modifiers.command == .locked)
        XCTAssertTrue(modifiers.consumeCommandForPointerLinkActivation())
        XCTAssertTrue(modifiers.command == .locked)
    }

    /// The user's OpenCode link tap failed because that TUI owns terminal
    /// mouse reporting. The explicit Command accessory route must bypass the
    /// capture, refresh a repeated pointer position, and deliver Ghostty's URL
    /// action to the host without emitting the click to OpenCode.
    func testCommandArmedTapOpensLinkInsideMouseCapturedOpenCodeStyleTerminal() async throws {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        let state = TerminalViewState()
        var openedURL: String?
        state.onOpenURL = { value, _ in openedURL = value }

        let terminal = UITerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        terminal.controller = state.controller
        terminal.delegate = state
        terminal.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        terminal.isResponderEligible = true
        let controller = UIViewController()
        controller.view = terminal
        let window = UIWindow(frame: terminal.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await Task.yield()
        await Task.yield()
        let surface = try XCTUnwrap(terminal.surface)
        session.receive(Data("https://example.com\r\n\u{1B}[?1000h".utf8))
        await Task.yield()
        XCTAssertTrue(surface.isMouseCaptured)

        let linkPoint = CGPoint(x: 40, y: 13)
        terminal.handleTerminalTap(state: .ended, location: linkPoint)
        terminal.toggleStickyModifier(.command)
        terminal.handleTerminalTap(state: .ended, location: linkPoint)

        XCTAssertEqual(openedURL, "https://example.com")
        XCTAssertEqual(terminal.stickyActivation(for: .command), .inactive)
    }

    func testOnlyCompletedTapRequestsFirstResponderWithoutSurface() {
        let (terminal, window) = makeEligibleWindowedTerminal()
        defer { window.isHidden = true }

        terminal.handleTerminalTap(state: .possible, location: .zero)
        terminal.handleTerminalTap(state: .cancelled, location: .zero)
        XCTAssertFalse(terminal.isFirstResponder)

        terminal.handleTerminalTap(state: .ended, location: .zero)
        XCTAssertTrue(terminal.isFirstResponder)
        XCTAssertNil(terminal.surface)
    }

    func testScrollSelectionPinchAndMomentumNeverRequestFirstResponder() {
        let (terminal, window) = makeEligibleWindowedTerminal()
        defer {
            terminal.stopMomentumScrolling()
            window.isHidden = true
        }

        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .began))
        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .cancelled))
        terminal.handleTerminalSelectionGesture(TestLongPressGestureRecognizer(state: .began))
        terminal.handlePinchGesture(TestPinchGestureRecognizer(state: .began, scale: 1))
        terminal.handlePinchGesture(TestPinchGestureRecognizer(state: .changed, scale: 1.2))
        terminal.startMomentumScrolling(velocity: CGPoint(x: 0, y: 1_000))

        XCTAssertFalse(terminal.isFirstResponder)
    }

    /// A normal one-finger scroll must get a chance to cross UIKit's pan
    /// threshold before the terminal claims the touch as text selection. The
    /// prior aggressive hold/movement values reproduced the user's drag as a
    /// blue selection with the Copy menu instead of scrolling Claude/Codex.
    func testOneFingerScrollingIsNotPrematurelyCapturedAsTextSelection() {
        let terminal = UITerminalView(frame: .zero)

        XCTAssertEqual(
            terminal.terminalSelectionGestureRecognizer.minimumPressDuration,
            UITerminalView.selectionMinimumPressDuration
        )
        XCTAssertEqual(
            terminal.terminalSelectionGestureRecognizer.allowableMovement,
            UITerminalView.selectionAllowableMovement
        )
        XCTAssertGreaterThanOrEqual(
            terminal.terminalSelectionGestureRecognizer.minimumPressDuration,
            0.5
        )
        XCTAssertLessThanOrEqual(
            terminal.terminalSelectionGestureRecognizer.allowableMovement,
            10
        )
        XCTAssertEqual(terminal.terminalScrollGestureRecognizer.minimumNumberOfTouches, 1)
        XCTAssertEqual(terminal.terminalScrollGestureRecognizer.maximumNumberOfTouches, 1)
    }

    /// Build 11 placed both native handles at the raw long-press points, so
    /// Ghostty's word/cell snapping could leave the visible endpoints collapsed
    /// or detached from the highlight. The C boundary must return content-free
    /// surface geometry and UIKit must anchor its distinct leading/trailing
    /// controls to that range instead of either initiating touch.
    func testSelectionHandlesUseGhosttyRangeInsteadOfLongPressTouchPoints() async throws {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        let terminal = UITerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        terminal.controller = TerminalController()
        terminal.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        let controller = UIViewController()
        controller.view = terminal
        let window = UIWindow(frame: terminal.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await Task.yield()
        await Task.yield()
        let surface = try XCTUnwrap(terminal.surface)
        session.receive(Data("0123456789 abcdefghij\r\nsecond line\r\n".utf8))
        await Task.yield()

        let initiatingTouch = CGPoint(x: 17.25, y: 12.75)
        let endingTouch = CGPoint(x: 121.5, y: 35.25)
        let mods = ghostty_input_mods_e(rawValue: 0)
        surface.sendMousePos(x: initiatingTouch.x, y: initiatingTouch.y, mods: mods)
        surface.sendMouseButton(
            state: GHOSTTY_MOUSE_PRESS,
            button: GHOSTTY_MOUSE_LEFT,
            mods: mods
        )
        surface.sendMousePos(x: endingTouch.x, y: endingTouch.y, mods: mods)
        surface.sendMouseButton(
            state: GHOSTTY_MOUSE_RELEASE,
            button: GHOSTTY_MOUSE_LEFT,
            mods: mods
        )

        terminal.ownsTerminalSelectionRange = true
        XCTAssertTrue(terminal.synchronizeSelectionHandlesWithSurface())
        let range = try XCTUnwrap(surface.selectionRange())
        let leading = try XCTUnwrap(range.leading)
        let trailing = try XCTUnwrap(range.trailing)

        XCTAssertNotEqual(leading, initiatingTouch)
        XCTAssertNotEqual(trailing, endingTouch)
        XCTAssertEqual(terminal.selectionStartPoint, leading)
        XCTAssertEqual(terminal.selectionEndPoint, trailing)
        XCTAssertEqual(terminal.startSelectionHandle.frame.maxY, leading.y, accuracy: 0.001)
        XCTAssertEqual(terminal.endSelectionHandle.frame.minY, trailing.y, accuracy: 0.001)
        XCTAssertLessThan(leading.x, trailing.x)
        XCTAssertLessThan(leading.y, trailing.y)
    }

    /// Build 6 fired an asynchronous refresh and immediately routed from the
    /// stale value, so the first Claude/Codex swipe still did nothing useful.
    /// Movement must stay buffered until the exact-client result arrives and
    /// then enter host history without emitting terminal wheel/cursor input.
    func testFirstCodingAgentSwipeWaitsForFreshContextBeforeUsingHostHistory() async {
        let terminal = UITerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let contextRequested = expectation(description: "context requested")
        let scrollRouted = expectation(description: "scroll routed")
        var providerCallCount = 0
        var routedLines: [Int] = []
        terminal.touchActionHandler = { action in
            if case let .verticalScroll(lines) = action {
                routedLines.append(lines)
                scrollRouted.fulfill()
            }
            return true
        }
        terminal.touchScrollContextProvider = {
            providerCallCount += 1
            contextRequested.fulfill()
            try? await Task.sleep(for: .milliseconds(30))
            return .hostScrollback
        }

        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .began))
        await fulfillment(of: [contextRequested], timeout: 1)
        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(
            state: .changed,
            translation: CGPoint(x: 0, y: 48)
        ))
        XCTAssertEqual(routedLines, [], "movement must remain buffered while context is stale")

        await fulfillment(of: [scrollRouted], timeout: 1)
        XCTAssertEqual(providerCallCount, 1)
        XCTAssertEqual(routedLines, [2])
        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .ended))
    }

    /// Codex can keep its output on the primary screen. Sending wheel input
    /// was ineffective in build 6, while tmux copy mode worked but trapped the
    /// user in a second interaction mode. A verified primary-screen agent must
    /// move Ghostty's own viewport directly and emit neither PTY nor host input.
    func testPrimaryScreenCodingAgentSwipeUsesLocalScrollbackWithoutTmuxCopyMode() async throws {
        let recorder = TerminalInputRecorder()
        let session = InMemoryTerminalSession(
            write: { recorder.append($0) },
            resize: { _ in }
        )
        let state = TerminalViewState()
        let terminal = UITerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        terminal.controller = state.controller
        terminal.delegate = state
        terminal.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        var hostActions: [TerminalTouchAction] = []
        terminal.touchActionHandler = { action in
            hostActions.append(action)
            return true
        }
        terminal.touchScrollContextProvider = { .localScrollback }

        let controller = UIViewController()
        controller.view = terminal
        let window = UIWindow(frame: terminal.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        await Task.yield()
        await Task.yield()

        let output = (0 ..< 100).map { "line-\($0)\r\n" }.joined()
        session.receive(Data(output.utf8))
        for _ in 0 ..< 100 {
            if let position = state.scrollbarPosition,
               position.total > position.length,
               position.isAtBottom
            {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let bottom = try XCTUnwrap(state.scrollbarPosition)
        XCTAssertGreaterThan(bottom.total, bottom.length)
        XCTAssertTrue(bottom.isAtBottom)

        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .began))
        await Task.yield()
        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(
            state: .changed,
            translation: CGPoint(x: 0, y: 80)
        ))
        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .ended))
        for _ in 0 ..< 100 {
            if let position = state.scrollbarPosition,
               position.offset < bottom.offset
            {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }

        let scrolled = try XCTUnwrap(state.scrollbarPosition)
        XCTAssertLessThan(scrolled.offset, bottom.offset)
        XCTAssertTrue(hostActions.isEmpty)
        XCTAssertEqual(recorder.data, Data())
    }

    func testHostFontSetterDoesNotPublishButInteractiveChangeDoes() {
        let terminal = UITerminalView(frame: .zero)
        var published: [Float] = []
        terminal.terminalFontSizeDidChange = { published.append($0) }

        terminal.setTerminalFontSize(18)
        XCTAssertEqual(published, [])
        XCTAssertEqual(terminal.configuration.fontSize, 18)
        terminal.recordBindingFontSizeChange(19)
        XCTAssertEqual(published, [19])
        XCTAssertEqual(terminal.configuration.fontSize, 19)
        terminal.recordBindingFontSizeChange(19)
        XCTAssertEqual(published, [19])
    }

    func testPinchAndHardwareZoomPublishOnceAndClampWithoutDuplicates() {
        let terminal = UITerminalView(frame: .zero)
        var published: [Float] = []
        terminal.terminalFontSizeDidChange = { published.append($0) }

        terminal.handlePinchGesture(TestPinchGestureRecognizer(state: .began, scale: 1))
        terminal.handlePinchGesture(TestPinchGestureRecognizer(state: .changed, scale: 1.2))
        XCTAssertEqual(published.count, 1)

        terminal.recordKeyboardZoomFontSizeChange(increases: true)
        XCTAssertEqual(published.count, 2)

        terminal.recordBindingFontSizeChange(1_000)
        terminal.recordBindingFontSizeChange(1_000)
        XCTAssertEqual(published.last, 64)
        XCTAssertEqual(published.filter { $0 == 64 }.count, 1)
        XCTAssertEqual(UITerminalView.validatedFontSize(12.5), 13)
    }

    func testPinchZoomCannotShrinkTerminalBelowReadableStartupSize() {
        XCTAssertEqual(UITerminalView.validatedFontSize(7), 10)
    }

    private func makeEligibleWindowedTerminal() -> (UITerminalView, UIWindow) {
        let terminal = UITerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        terminal.isResponderEligible = true
        let controller = UIViewController()
        controller.view = terminal
        let window = UIWindow(frame: terminal.bounds)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return (terminal, window)
    }

    private func testAction(
        id: String,
        handler: @escaping () -> Void
    ) -> TerminalInputAccessoryAction {
        TerminalInputAccessoryAction(
            id: id,
            accessibilityLabel: "Action \(id)",
            systemImage: "bolt",
            handler: handler
        )
    }

    private func tapButton(label: String, in view: UIView) throws {
        let button = try XCTUnwrap(findButton(label: label, in: view))
        button.sendActions(for: .touchUpInside)
    }

    private func findButton(label: String, in view: UIView) -> UIButton? {
        if let button = view as? UIButton, button.accessibilityLabel == label {
            return button
        }
        return view.subviews.lazy.compactMap { self.findButton(label: label, in: $0) }.first
    }
}

private final class TerminalInputRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }
}

private final class TestPanGestureRecognizer: UIPanGestureRecognizer {
    private let testState: UIGestureRecognizer.State
    private let testTranslation: CGPoint
    private let testVelocity: CGPoint

    init(
        state: UIGestureRecognizer.State,
        translation: CGPoint = .zero,
        velocity: CGPoint = .zero
    ) {
        testState = state
        testTranslation = translation
        testVelocity = velocity
        super.init(target: nil, action: nil)
    }

    override var state: UIGestureRecognizer.State {
        get { testState }
        set { /* Test state is fixed at construction. */ }
    }

    override func translation(in _: UIView?) -> CGPoint { testTranslation }
    override func setTranslation(_: CGPoint, in _: UIView?) {}
    override func velocity(in _: UIView?) -> CGPoint { testVelocity }
}

private final class TestLongPressGestureRecognizer: UILongPressGestureRecognizer {
    private let testState: UIGestureRecognizer.State

    init(state: UIGestureRecognizer.State) {
        testState = state
        super.init(target: nil, action: nil)
    }

    override var state: UIGestureRecognizer.State {
        get { testState }
        set { /* Test state is fixed at construction. */ }
    }
}

private final class TestPinchGestureRecognizer: UIPinchGestureRecognizer {
    private let testState: UIGestureRecognizer.State

    init(state: UIGestureRecognizer.State, scale: CGFloat) {
        testState = state
        super.init(target: nil, action: nil)
        self.scale = scale
    }

    override var state: UIGestureRecognizer.State {
        get { testState }
        set { /* Test state is fixed at construction. */ }
    }
}
#endif
