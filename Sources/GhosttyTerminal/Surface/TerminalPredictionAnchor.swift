import Foundation

/// Content-free location of Ghostty's authoritative cursor when a speculative
/// terminal prediction begins. The grid dimensions make an anchor fail closed
/// after a resize rather than reading a different cell at the old coordinates.
public struct TerminalPredictionAnchor: Equatable, Sendable {
    public let column: UInt32
    public let row: UInt32
    public let columns: UInt16
    public let rows: UInt16

    public init(column: UInt32, row: UInt32, columns: UInt16, rows: UInt16) {
        self.column = column
        self.row = row
        self.columns = columns
        self.rows = rows
    }
}

/// Resolves the C API's IME point back to a grid cell without exposing terminal
/// text. Ghostty reports the cursor's horizontal midpoint and vertical bottom
/// in logical points, while grid metrics are in pixels. The candidate padding
/// values cover Ghostty's default zero-padding and its balanced-padding modes;
/// an explicit custom padding that cannot be proven returns nil.
enum TerminalPredictionGeometry {
    static func anchor(
        metrics: TerminalGridMetrics,
        imePoint: (x: Double, y: Double, width: Double, height: Double)
    ) -> TerminalPredictionAnchor? {
        guard metrics.columns > 0,
              metrics.rows > 0,
              metrics.cellWidthPixels > 0,
              metrics.cellHeightPixels > 0,
              imePoint.height > 0
        else { return nil }

        let cellWidth = Double(metrics.cellWidthPixels)
        let cellHeight = Double(metrics.cellHeightPixels)
        let scale = cellHeight / imePoint.height
        guard scale.isFinite, scale > 0 else { return nil }

        let rawX = imePoint.x * scale
        let rawY = imePoint.y * scale
        let occupiedWidth = UInt32(metrics.columns) * metrics.cellWidthPixels
        let occupiedHeight = UInt32(metrics.rows) * metrics.cellHeightPixels
        let horizontalRemainder = metrics.widthPixels >= occupiedWidth
            ? metrics.widthPixels - occupiedWidth
            : 0
        let verticalRemainder = metrics.heightPixels >= occupiedHeight
            ? metrics.heightPixels - occupiedHeight
            : 0
        let horizontalPadding = candidates(0, horizontalRemainder / 2)
        let verticalPadding = candidates(
            0,
            verticalRemainder / 2,
            min(verticalRemainder / 2, metrics.cellWidthPixels / 2)
        )

        guard let column = coordinate(
            rawPoint: rawX,
            cellExtent: cellWidth,
            pointOffset: cellWidth / 2,
            count: Int(metrics.columns),
            paddingCandidates: horizontalPadding
        ), let row = coordinate(
            rawPoint: rawY,
            cellExtent: cellHeight,
            pointOffset: cellHeight,
            count: Int(metrics.rows),
            paddingCandidates: verticalPadding
        ) else { return nil }

        return TerminalPredictionAnchor(
            column: UInt32(column),
            row: UInt32(row),
            columns: metrics.columns,
            rows: metrics.rows
        )
    }

    private static func coordinate(
        rawPoint: Double,
        cellExtent: Double,
        pointOffset: Double,
        count: Int,
        paddingCandidates: [UInt32]
    ) -> Int? {
        for padding in paddingCandidates {
            let exact = (rawPoint - Double(padding) - pointOffset) / cellExtent
            let candidate = Int(exact.rounded())
            guard candidate >= 0, candidate < count else { continue }
            let reconstructed = Double(padding) + Double(candidate) * cellExtent + pointOffset
            if abs(reconstructed - rawPoint) <= 1 {
                return candidate
            }
        }
        return nil
    }

    private static func candidates(_ values: UInt32...) -> [UInt32] {
        var result: [UInt32] = []
        for value in values where !result.contains(value) {
            result.append(value)
        }
        return result
    }
}
