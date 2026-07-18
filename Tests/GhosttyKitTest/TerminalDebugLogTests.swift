@testable import GhosttyTerminal
import Foundation
import Testing

@Suite(.serialized)
struct TerminalDebugLogTests {
    @Test
    func loggingIsDisabledByDefault() {
        withRestoredDebugLogState {
            #expect(!TerminalDebugLog.isEnabled)
            #expect(TerminalDebugLog.categories == .standard)
            #expect(!TerminalDebugLog.categories.contains(.render))
        }
    }

    @Test
    func loggingCanBeToggledAndReconfigured() {
        withRestoredDebugLogState {
            TerminalDebugLog.disable()
            #expect(!TerminalDebugLog.isEnabled)

            TerminalDebugLog.enable(.all)
            TerminalDebugLog.sink = { _ in }

            #expect(TerminalDebugLog.isEnabled)
            #expect(TerminalDebugLog.categories == .all)
        }
    }

    @Test
    func descriptionsNeverIncludeTerminalContent() {
        #expect(TerminalDebugLog.describe(Data([0x73, 0x65, 0x63, 0x72, 0x65, 0x74])) == "bytes=6")
        #expect(TerminalDebugLog.describe("secret") == "characters=6")
    }

    @Test
    func inputBoundaryLogsNeverIncludePayloadContent() {
        withRestoredDebugLogState {
            let capture = DebugLogCapture()
            let sentinel = "SKERRY_PRIVATE_INPUT_4D3A9C"
            let data = Data(sentinel.utf8)
            let session = InMemoryTerminalSession(
                write: { _ in },
                resize: { _ in }
            )

            TerminalDebugLog.sink = { capture.append($0) }
            TerminalDebugLog.enable([.input, .output])

            session.sendInput(data)
            session.receive(data)

            let output = capture.combinedMessages
            #expect(!output.contains(sentinel))
            #expect(output.contains("bytes=\(data.count)"))
        }
    }

    @Test
    func debugSinkNeverIncludesKeyContentOrIdentity() {
        withRestoredDebugLogState {
            let capture = DebugLogCapture()
            let inputSentinel = "SKERRY_KEY_CONTENT_8C72F1"
            let identitySentinel = "SKERRY_HID_NATIVE_KEY_91B6E4"

            TerminalDebugLog.sink = { capture.append($0) }
            TerminalDebugLog.enable(.input)
            TerminalDebugLog.log(
                .input,
                "key content=\(TerminalDebugLog.describe(inputSentinel)) identity=\(TerminalDebugLog.describe(identitySentinel))"
            )

            let output = capture.combinedMessages
            #expect(!output.contains(inputSentinel))
            #expect(!output.contains(identitySentinel))
            #expect(output.contains("content=characters=\(inputSentinel.count)"))
            #expect(output.contains("identity=characters=\(identitySentinel.count)"))
        }
    }
}

private func withRestoredDebugLogState(
    _ body: () -> Void
) {
    let originalEnabled = TerminalDebugLog.isEnabled
    let originalCategories = TerminalDebugLog.categories
    let originalSink = TerminalDebugLog.sink
    defer {
        TerminalDebugLog.isEnabled = originalEnabled
        TerminalDebugLog.categories = originalCategories
        TerminalDebugLog.sink = originalSink
    }

    body()
}

private final class DebugLogCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var messages: [String] = []

    func append(_ message: String) {
        lock.lock()
        messages.append(message)
        lock.unlock()
    }

    var combinedMessages: String {
        lock.lock()
        defer { lock.unlock() }
        return messages.joined(separator: "\n")
    }
}
