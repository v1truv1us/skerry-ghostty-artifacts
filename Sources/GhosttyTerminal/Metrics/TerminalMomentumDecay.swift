//
//  TerminalMomentumDecay.swift
//  libghostty-spm
//

import CoreGraphics
import Foundation

/// Momentum scroll decay as a pure function of elapsed time. The display
/// link fires at the panel's refresh rate, so a fixed per-frame multiplier
/// decays a fling twice as fast on a 120Hz iPad as on a 60Hz iPhone.
/// Scaling the 60Hz-tuned multiplier by `dt` keeps the wall-clock feel
/// identical at any refresh rate.
enum TerminalMomentumDecay {
    static let perFrameMultiplierAt60Hz: Double = 0.92

    static func decayedVelocity(_ velocity: CGPoint, dt: TimeInterval) -> CGPoint {
        guard dt > 0 else { return velocity }
        let factor = pow(perFrameMultiplierAt60Hz, dt * 60)
        return CGPoint(x: velocity.x * factor, y: velocity.y * factor)
    }
}
