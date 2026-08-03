@testable import GhosttyTerminal
import Foundation
import Testing

struct TerminalMomentumDecayTests {
    /// User-visible failure: on a 120Hz ProMotion iPad a scroll fling died
    /// roughly twice as fast as on a 60Hz iPhone, because decay was applied
    /// per display-link frame instead of per unit of time.
    @Test
    func flingDecaysEquallyPerSecondAtAnyRefreshRate() {
        let velocity = CGPoint(x: 0, y: 1000)

        var at60Hz = velocity
        for _ in 0 ..< 60 {
            at60Hz = TerminalMomentumDecay.decayedVelocity(at60Hz, dt: 1.0 / 60.0)
        }

        var at120Hz = velocity
        for _ in 0 ..< 120 {
            at120Hz = TerminalMomentumDecay.decayedVelocity(at120Hz, dt: 1.0 / 120.0)
        }

        #expect(abs(at60Hz.y - at120Hz.y) < 0.01)
    }

    /// A zero-duration frame (duplicate display-link callback) must not
    /// decay at all, or fast panels would still lose extra speed.
    @Test
    func zeroElapsedTimeLeavesVelocityUntouched() {
        let velocity = CGPoint(x: 100, y: -250)
        #expect(TerminalMomentumDecay.decayedVelocity(velocity, dt: 0) == velocity)
    }
}
