#if canImport(UIKit) && !targetEnvironment(macCatalyst)
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

    /// Skerry re-polls tmux's `alternate_on` only on an explicit selection or
    /// bell, so it must learn a scroll is starting to re-check screen mode
    /// before Codex/Claude, launched in the pane already on screen, get
    /// misrouted through the wheel-to-arrow-key fallback that reads as
    /// prompt-history recall instead of scrollback. The hook must fire
    /// exactly on `.began`, not on every gesture state.
    func testScrollGestureBeginningNotifiesHostToRefreshScreenMode() {
        let terminal = UITerminalView(frame: .zero)
        var callCount = 0
        terminal.scrollGestureWillBeginHandler = { callCount += 1 }

        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .began))
        XCTAssertEqual(callCount, 1)

        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .changed))
        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .ended))
        terminal.handleTouchScrollGesture(TestPanGestureRecognizer(state: .cancelled))
        XCTAssertEqual(callCount, 1)
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

    init(state: UIGestureRecognizer.State) {
        testState = state
        super.init(target: nil, action: nil)
    }

    override var state: UIGestureRecognizer.State {
        get { testState }
        set { /* Test state is fixed at construction. */ }
    }
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
