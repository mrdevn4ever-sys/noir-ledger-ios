import NoirCore
import SwiftUI
import UIKit

/// One decorative surface per staffed floor. Only geometry, staffing and decoded artwork enter it;
/// no display-link callback has to visit SwiftUI just to move an already painted worker.
struct StaffedCrew: View {
    let good: Good
    let count: Int
    let shelf: CGFloat
    let start: CGFloat
    let end: CGFloat
    @Environment(\.sceneAnimating) private var animating

    var body: some View {
        let cache = SceneImages.shared
        let walk = cache.sheet(SceneArt.worker(good, .walk), frames: SceneArt.Move.walk.frames)
        let work = cache.sheet(SceneArt.worker(good, .work), frames: SceneArt.Move.work.frames)
        let carry = cache.sheet(SceneArt.worker(good, .carry), frames: SceneArt.Move.carry.frames)
        if let walk, let work, let carry {
            CrewSurface(walk: walk, work: work, carry: carry, count: count, shelf: shelf, start: start, end: end, active: animating)
        } else {
            // Keep each person visible even on the first draw, before the background decoder has finished.
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
}

private struct CrewSurface: UIViewRepresentable {
    let walk: SpriteSheet
    let work: SpriteSheet
    let carry: SpriteSheet
    let count: Int
    let shelf: CGFloat
    let start: CGFloat
    let end: CGFloat
    let active: Bool

    func makeUIView(context: Context) -> CrewLayerView { CrewLayerView(frame: .zero) }

    func updateUIView(_ view: CrewLayerView, context: Context) {
        view.configure(sheets: [walk, work, carry], count: count, shelf: shelf, start: start, end: end, active: active)
    }
}

/// Core Animation interpolates travel independently of the drawing rate of the flipbooks.
/// All three poses keep their own trimmed rectangles, including the mirrored return trip.
final class CrewLayerView: UIView {
    private struct Setup: Equatable {
        let ids: [ObjectIdentifier]
        let count: Int
        let shelf, start, end: CGFloat
    }
    private var setup: Setup?
    private var sheets: [SpriteSheet] = []
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
        precondition(sheets.count == 3)
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
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let size = SceneFigure.size(1)
        let now = layer.convertTime(CACurrentMediaTime(), from: nil)
        for i in 0..<setup.count {
            let station = CrewRoute.station(i, start: setup.start, end: setup.end)
            let actor = CALayer()
            actor.bounds = CGRect(origin: .zero, size: size)
            actor.position = CGPoint(x: station, y: size.height / 2)
            layer.addSublayer(actor)
            if !active {
                _ = paint(sheets[1], mirrored: false, in: actor)
                continue
            }
            // All layers in a route use the same media-time origin, even when a floor scrolls back into view.
            let period = CrewRoute.period
            let origin = now - (now + Double(i) * 2.3).truncatingRemainder(dividingBy: period)
            let times: [NSNumber] = [0, 0.3, 0.6, 1]
            let motion = CAKeyframeAnimation(keyPath: "position.x")
            motion.values = [setup.shelf, station, station, setup.shelf]
            motion.keyTimes = times
            motion.calculationMode = .linear
            motion.duration = period
            motion.beginTime = origin
            motion.repeatCount = .infinity
            actor.add(motion, forKey: "route")
            for (phase, sheet) in sheets.enumerated() {
                let pose = paint(sheet, mirrored: phase == 2, in: actor)
                let gate = CAKeyframeAnimation(keyPath: "opacity")
                gate.values = [0, 1, 2, 0].map { $0 == phase ? 1.0 : 0.0 }
                gate.keyTimes = times
                gate.calculationMode = .discrete
                gate.duration = period
                gate.beginTime = origin
                gate.repeatCount = .infinity
                pose.add(gate, forKey: "pose")
                let frames = CAKeyframeAnimation(keyPath: "contents")
                frames.values = sheet.frames
                frames.calculationMode = .discrete
                frames.duration = Double(sheet.frames.count) / (phase == 1 ? SceneArt.Move.work.fps : SceneArt.Move.walk.fps)
                frames.beginTime = origin
                frames.repeatCount = .infinity
                pose.add(frames, forKey: "frames")
            }
        }
    }

    private func paint(_ sheet: SpriteSheet, mirrored: Bool, in actor: CALayer) -> CALayer {
        let size = actor.bounds.size
        let crop = sheet.crop
        let sprite = CALayer()
        sprite.frame = CGRect(x: (mirrored ? 1 - crop.maxX : crop.minX) * size.width, y: crop.minY * size.height,
                              width: crop.width * size.width, height: crop.height * size.height)
        sprite.contents = sheet.frames.first
        if mirrored { sprite.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) }
        actor.addSublayer(sprite)
        return sprite
    }
}
