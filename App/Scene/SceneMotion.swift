import NoirCore
import QuartzCore
import SwiftUI

/*
 * How the scene moves without redrawing itself: the building is laid out once per simulation tick (four times a
 * second); only small leaf views carry their own clock. Sprite frames tick at their own rate (2–14 frames a second);
 * things that travel (vehicle, lift, walkers, progress bars) run at the display's rate and read the simulation
 * between its ticks, so nothing jumps four times a second. Everything stops while the scene is covered or scrolled
 * away, and with reduced motion.
 */

extension EnvironmentValues {
    /// False while a sheet covers the scene, while this part is scrolled out of view, or with reduced motion.
    @Entry var sceneAnimating = true
}

extension LedgerStore {
    /// Simulation seconds since the last tick, to draw what happened in between (never more than one tick and a half).
    func sinceTick(_ date: Date) -> Double {
        let real = min(Self.tickInterval * 1.5, max(0, date.timeIntervalSinceReferenceDate - lastTickAt))
        return timeScale > 1 ? real * timeScale : real
    }

    /// The trip's phase (0–1) at `date`: 0–0.5 the lift collects, 0.5–0.75 the vehicle drives over, 0.75–1 it returns.
    func tripPhase(_ state: FlowState, at date: Date) -> Double {
        guard let trip = state.trip else { return 0 }
        return min(1, max(0, 1 - max(0, trip.left - sinceTick(date)) / max(0.1, trip.duration)))
    }
}

/// A sprite sheet that plays on its own clock.
struct AnimatedStrip: View {
    let name: String
    let frames: Int
    let fps: Double
    let size: CGSize
    var phase: Double = 0
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / fps, paused: !animating)) { tl in
            SpriteStrip(name: name, frames: frames, frame: Int((tl.date.timeIntervalSinceReferenceDate + phase) * fps), size: size)
        }
    }
}

/// A sprite sheet that plays once whenever `start` changes to a new moment, then disappears.
struct OneShotStrip: View {
    let name: String
    let frames: Int
    let size: CGFloat
    /// Reference-date seconds of the moment it starts; 0 for never.
    let start: Double
    var fps: Double = 12
    @State private var done = 0.0

    var body: some View {
        if start > 0, done != start {
            TimelineView(.animation(minimumInterval: 1 / fps)) { tl in
                let f = Int((tl.date.timeIntervalSinceReferenceDate - start) * fps)
                if f >= 0 && f < frames {
                    SpriteStrip(name: name, frames: frames, frame: f, size: CGSize(width: size, height: size))
                }
            }
            .allowsHitTesting(false)
            .task(id: start) {
                try? await Task.sleep(for: .seconds(Double(frames) / fps + 0.1))
                done = start
            }
        }
    }
}

/// Endless small motions drawn by the render server (no redraw of the view): bobbing, pulsing, swaying, glowing.
struct IdleMotion: ViewModifier {
    enum Kind { case bob(CGFloat), pulse(CGFloat), sway(Double), glow(Double) }
    let kind: Kind
    var duration: Double = 1
    @State private var on = false
    @Environment(\.sceneAnimating) private var animating

    func body(content: Self.Content) -> some View {
        let active = on && animating
        Group {
            switch kind {
            case .bob(let d): content.offset(y: active ? d : 0)
            case .pulse(let s): content.scaleEffect(active ? s : 1)
            case .sway(let a): content.rotationEffect(.degrees(active ? a : -a))
            case .glow(let o): content.opacity(active ? 1 : o)
            }
        }
        .animation(animating ? .easeInOut(duration: duration).repeatForever(autoreverses: true) : .default, value: active)
        .onAppear { on = true }
    }
}

extension View {
    func idle(_ kind: IdleMotion.Kind, duration: Double = 1) -> some View { modifier(IdleMotion(kind: kind, duration: duration)) }
}
