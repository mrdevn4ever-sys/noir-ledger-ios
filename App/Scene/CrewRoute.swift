import NoirCore
import SwiftUI
import UIKit

/// No display clock or simulation state enters the staffed floor. Until all three sheets are
/// ready, draw stationary workers through the normal cache-backed fallback.
struct StaffedCrew: View {
    let good: Good
    let count: Int
    let shelf, start, end: CGFloat
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        let cache = SceneImages.shared
        let walk = cache.sheet(SceneArt.worker(good, .walk), frames: SceneArt.Move.walk.frames)
        let work = cache.sheet(SceneArt.worker(good, .work), frames: SceneArt.Move.work.frames)
        let carry = cache.sheet(SceneArt.worker(good, .carry), frames: SceneArt.Move.carry.frames)
        if let walk, let work, let carry {
            CrewSurface(walk: walk, work: work, carry: carry, count: count, shelf: shelf, start: start, end: end, active: animating)
        } else {
            ZStack(alignment: .topLeading) {
                ForEach(0..<count, id: \.self) { i in
                    SpriteStrip(name: SceneArt.worker(good, .work), frames: 4, frame: i, size: SceneFigure.size(1))
                        .offset(x: CrewRoute.station(i, start: start, end: end) - SceneFigure.size(1).width / 2)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

enum CrewRoute {
    static let period = 7.0
    static func station(_ index: Int, start: CGFloat, end: CGFloat) -> CGFloat {
        start + (end - start) * (0.15 + 0.35 * CGFloat(index))
    }

    // Discrete artwork on a common timebase, not a 30 Hz display clock. Travel stays continuous.
    // At 10/6/10 frames per second, phase boundaries and every image change fall on integer ticks.
    static let samples: [(time: Double, pose: Int, frame: Int)] = {
        let phases = [(0..<63, 3, 8), (63..<126, 5, 4), (126..<210, 3, 8)]
        var result: [(Double, Int, Int)] = []
        for (pose, phase) in phases.enumerated() {
            let (range, step, count) = phase
            for tick in stride(from: range.lowerBound, to: range.upperBound, by: step) {
                result.append((Double(tick) / 210, pose, (tick - range.lowerBound) / step % count))
            }
        }
        result.append((1, 0, 0))
        return result
    }()

    /// Map the full layer rectangle onto the trimmed frame, reflecting about the *original*
    /// figure's centre on the return trip, not about the trimmed image's centre.
    static func registration(_ crop: CGRect, size: CGSize, mirrored: Bool) -> CGAffineTransform {
        let sign: CGFloat = mirrored ? -1 : 1
        return CGAffineTransform(a: sign * crop.width, b: 0, c: 0, d: crop.height,
                                 tx: sign * (crop.midX - 0.5) * size.width, ty: (crop.midY - 0.5) * size.height)
    }
}

private struct CrewSurface: UIViewRepresentable {
    let walk, work, carry: SpriteSheet
    let count: Int
    let shelf, start, end: CGFloat
    let active: Bool

    func makeUIView(context: Context) -> CrewLayerView { CrewLayerView(frame: .zero) }
    func updateUIView(_ view: CrewLayerView, context: Context) {
        view.configure(sheets: [walk, work, carry], count: count, shelf: shelf, start: start, end: end, active: active)
    }
}

/// One image-bearing layer per person. Pose changes swap its contents and registration;
/// changing visibility only adds/removes animations, never more layers or decoded frames.
final class CrewLayerView: UIView {
    private struct Setup: Equatable {
        let ids: [ObjectIdentifier]
        let count: Int
        let shelf, start, end: CGFloat
    }
    private var setup: Setup?
    private var sheets: [SpriteSheet] = []
    private var actors: [CALayer] = []
    private var requested = false
    private var playing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        isOpaque = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { nil }

    func configure(sheets: [SpriteSheet], count: Int, shelf: CGFloat, start: CGFloat, end: CGFloat, active: Bool) {
        let next = Setup(ids: sheets.map { ObjectIdentifier($0) }, count: count, shelf: shelf, start: start, end: end)
        requested = active
        let changed = next != setup
        if changed { setup = next; self.sheets = sheets }
        refresh(force: changed)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refresh(force: false)
    }

    private func refresh(force: Bool) {
        let active = requested && window != nil
        guard let setup, force || active != playing else { return }
        playing = active
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        while actors.count > setup.count { actors.removeLast().removeFromSuperlayer() }
        while actors.count < setup.count {
            let actor = CALayer()
            actor.contentsGravity = .resize
            layer.addSublayer(actor)
            actors.append(actor)
        }
        let size = SceneFigure.size(1)
        let registrations = sheets.enumerated().map { CrewRoute.registration($0.element.crop, size: size, mirrored: $0.offset == 2) }
        // Frames are references to BGRA cache entries. Share the schedule across this floor.
        let samples = CrewRoute.samples
        let images: [CGImage] = active ? samples.map { sheets[$0.pose].frames[$0.frame] } : []
        let times: [NSNumber] = active ? samples.map { NSNumber(value: $0.time) } : []
        let transforms = [0, 1, 2, 0].map { NSValue(caTransform3D: CATransform3DMakeAffineTransform(registrations[$0])) }
        let boundaries: [NSNumber] = [0, 0.3, 0.6, 1]
        let now = layer.convertTime(CACurrentMediaTime(), from: nil)
        for (i, actor) in actors.enumerated() {
            actor.removeAllAnimations()
            let station = CrewRoute.station(i, start: setup.start, end: setup.end)
            actor.bounds = CGRect(origin: .zero, size: size)
            actor.position = CGPoint(x: station, y: size.height / 2)
            actor.contents = sheets[1].frames[i % sheets[1].frames.count]
            actor.setAffineTransform(registrations[1])
            guard active else { continue }
            let origin = now - (now + Double(i) * 2.3).truncatingRemainder(dividingBy: CrewRoute.period)
            func animate(_ path: String, _ values: [Any], _ keys: [NSNumber], _ mode: CAAnimationCalculationMode) {
                let animation = CAKeyframeAnimation(keyPath: path)
                animation.values = values
                animation.keyTimes = keys
                animation.calculationMode = mode
                animation.duration = CrewRoute.period
                animation.repeatCount = .infinity
                animation.beginTime = origin
                actor.add(animation, forKey: path)
            }
            animate("contents", images, times, .discrete)
            animate("transform", transforms, boundaries, .discrete)
            animate("position.x", [setup.shelf, station, station, setup.shelf], boundaries, .linear)
        }
    }
}
