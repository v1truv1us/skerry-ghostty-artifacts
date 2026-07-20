#if canImport(UIKit)
import XCTest
@testable import GhosttyTerminal

@MainActor
final class TerminalOpenURLTests: XCTestCase {
    func testTerminalViewStateForwardsRecognizedURLToHostPolicy() {
        let state = TerminalViewState()
        var receivedURL: String?
        var receivedTextKind = false
        state.onOpenURL = { url, kind in
            receivedURL = url
            if case .text = kind {
                receivedTextKind = true
            }
        }

        state.terminalDidRequestOpenURL("https://example.com/path", kind: .text)

        XCTAssertEqual(receivedURL, "https://example.com/path")
        XCTAssertTrue(receivedTextKind)
    }
}
#endif
