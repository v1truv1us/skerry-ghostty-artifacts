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
        return view.subviews.lazy.compactMap { findButton(label: label, in: $0) }.first
    }
}

private final class TestPanGestureRecognizer: UIPanGestureRecognizer {
    private let testState: UIGestureRecognizer.State

    init(state: UIGestureRecognizer.State) {
        testState = state
        super.init(target: nil, action: nil)
    }

    override var state: UIGestureRecognizer.State { testState }
}

private final class TestLongPressGestureRecognizer: UILongPressGestureRecognizer {
    private let testState: UIGestureRecognizer.State

    init(state: UIGestureRecognizer.State) {
        testState = state
        super.init(target: nil, action: nil)
    }

    override var state: UIGestureRecognizer.State { testState }
}

private final class TestPinchGestureRecognizer: UIPinchGestureRecognizer {
    private let testState: UIGestureRecognizer.State

    init(state: UIGestureRecognizer.State, scale: CGFloat) {
        testState = state
        super.init(target: nil, action: nil)
        self.scale = scale
    }

    override var state: UIGestureRecognizer.State { testState }
}
#endif
