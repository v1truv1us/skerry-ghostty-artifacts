import XCTest
@testable import GhosttyTerminal

final class TerminalPredictionGeometryTests: XCTestCase {
    func testResolvesDefaultZeroPaddingAtRetinaScale() throws {
        let metrics = TerminalGridMetrics(
            columns: 80,
            rows: 24,
            widthPixels: 800,
            heightPixels: 480,
            cellWidthPixels: 10,
            cellHeightPixels: 20
        )

        let anchor = try XCTUnwrap(TerminalPredictionGeometry.anchor(
            metrics: metrics,
            imePoint: (x: 27.5, y: 40, width: 0, height: 10)
        ))

        XCTAssertEqual(anchor.column, 5)
        XCTAssertEqual(anchor.row, 3)
    }

    func testResolvesBalancedPadding() throws {
        let metrics = TerminalGridMetrics(
            columns: 8,
            rows: 4,
            widthPixels: 88,
            heightPixels: 90,
            cellWidthPixels: 10,
            cellHeightPixels: 20
        )

        let anchor = try XCTUnwrap(TerminalPredictionGeometry.anchor(
            metrics: metrics,
            imePoint: (x: 29, y: 45, width: 0, height: 20)
        ))

        XCTAssertEqual(anchor.column, 2)
        XCTAssertEqual(anchor.row, 1)
    }

    func testRejectsGeometryThatCannotBeProven() {
        let metrics = TerminalGridMetrics(
            columns: 80,
            rows: 24,
            widthPixels: 800,
            heightPixels: 480,
            cellWidthPixels: 10,
            cellHeightPixels: 20
        )

        XCTAssertNil(TerminalPredictionGeometry.anchor(
            metrics: metrics,
            imePoint: (x: 3.25, y: 7.25, width: 0, height: 10)
        ))
    }
}
