import XCTest
@testable import GhosttyTerminal

@MainActor
final class TerminalSurfaceCoordinatorResizeTests: XCTestCase {
    func testFitToSizeIfChangedSkipsRedundantTickForUnchangedBounds() async {
        let coordinator = TerminalSurfaceCoordinator()
        coordinator.isAttached = { true }
        coordinator.scaleFactor = { 2.0 }
        var size = (width: 320.0, height: 480.0)
        coordinator.viewSize = { size }

        var renderCount = 0
        coordinator.onPostRender = { renderCount += 1 }

        coordinator.fitToSizeIfChanged()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(renderCount, 1)

        // A relayout pass reporting the same bounds (e.g. an unrelated
        // sibling view relaying out) must not force another resize/redraw.
        coordinator.fitToSizeIfChanged()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(renderCount, 1)

        // A real bounds change must still resynchronize and render.
        size = (width: 480.0, height: 320.0)
        coordinator.fitToSizeIfChanged()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(renderCount, 2)
    }

    func testFitToSizeAlwaysTicksRegardlessOfBoundsChange() async {
        let coordinator = TerminalSurfaceCoordinator()
        coordinator.isAttached = { true }
        coordinator.scaleFactor = { 2.0 }
        coordinator.viewSize = { (width: 320.0, height: 480.0) }

        var renderCount = 0
        coordinator.onPostRender = { renderCount += 1 }

        // Content-driven callers (font-size change, keyboard zoom) call
        // `fitToSize()` directly and must always get a scheduled render,
        // even though the view's own pixel bounds never move.
        coordinator.fitToSize()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(renderCount, 1)

        coordinator.fitToSize()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(renderCount, 2)
    }
}
