@testable import GhosttyTerminal
import Foundation
import Testing

@MainActor
struct InMemoryTerminalSessionViewportTests {
    /// A fresh session has never drawn anything, so its revision must start at
    /// a stable baseline that a caller can compare future readings against.
    @Test
    func outputRevisionStartsAtZero() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })
        #expect(session.currentOutputRevision() == 0)
    }

    /// Data received with no attached surface is dropped entirely, so it must
    /// never be mistaken for a real draw of new output. This is the
    /// safety-critical direction: a false "output happened" would let a
    /// recovery-metrics consumer count a frame that never rendered anything
    /// new.
    @Test
    func outputRevisionNeverAdvancesWithoutAnAttachedSurface() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })

        session.receive(Data("ignored".utf8))
        session.receive(Data("still ignored".utf8))

        #expect(session.currentOutputRevision() == 0)
    }

    /// An empty payload carries no visible content, so it must not be counted
    /// as output even if a surface happens to be attached.
    @Test
    func outputRevisionDoesNotAdvanceForEmptyData() {
        let session = InMemoryTerminalSession(write: { _ in }, resize: { _ in })

        session.receive(Data())

        #expect(session.currentOutputRevision() == 0)
    }
}
