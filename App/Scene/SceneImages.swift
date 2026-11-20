import NoirCore
import SwiftUI
import UIKit

/// A sprite sheet decoded and trimmed off the main thread: one small bitmap per frame, cut to the part of the frame
/// that has any colour (the union over all frames, so the frames stay aligned). Overlays such as the running machines
/// are mostly transparent; drawing only their visible part saves most of the blending and memory.
final class SpriteSheet: @unchecked Sendable {
    let frames: [CGImage]
    /// The trimmed rectangle in unit coordinates of one frame (0…1, origin top left).
    let crop: CGRect
    let cost: Int

    init(frames: [CGImage], crop: CGRect) {
        self.frames = frames
        self.crop = crop
        cost = frames.reduce(0) { $0 + $1.bytesPerRow * $1.height }
    }
}

/// The scene's image cache. Views ask for a sheet; the first ask starts decoding in the background and the view draws
/// the catalog image until the prepared sheet is there. `prewarm` decodes what the scene is about to show.
@MainActor
@Observable
final class SceneImages {
    static let shared = SceneImages()

    /// Bumps when a sheet is ready, so views that drew the fallback pick up the prepared one.
    private(set) var ready = 0
    @ObservationIgnored private let cache: NSCache<NSString, SpriteSheet> = {
        let c = NSCache<NSString, SpriteSheet>()
        c.totalCostLimit = 180 * 1024 * 1024
        return c
    }()
    @ObservationIgnored private var pending: Set<String> = []

    func sheet(_ name: String, frames: Int) -> SpriteSheet? {
        if let s = cache.object(forKey: name as NSString) { return s }
        // Only a view that had to draw the fallback watches for the prepared sheet.
        _ = ready
        load(name, frames: frames)
        return nil
    }

    func prewarm(_ items: [(name: String, frames: Int)]) {
        for item in items where cache.object(forKey: item.name as NSString) == nil { load(item.name, frames: item.frames) }
    }

    private func load(_ name: String, frames: Int) {
        guard !pending.contains(name) else { return }
        pending.insert(name)
        Task.detached(priority: .userInitiated) {
            let sheet = SceneImages.make(name, frames: frames)
            await MainActor.run {
                let images = SceneImages.shared
                images.pending.remove(name)
                if let sheet {
                    images.cache.setObject(sheet, forKey: name as NSString, cost: sheet.cost)
                    images.ready &+= 1
                }
            }
        }
    }

    /// Decodes the catalog image, finds the visible rectangle over all frames and copies each frame's part into
    /// its own bitmap.
    nonisolated static func make(_ name: String, frames n: Int) -> SpriteSheet? {
        guard let image = UIImage(named: name)?.cgImage else { return nil }
        return make(image, frames: n)
    }

    nonisolated static func make(_ image: CGImage, frames n: Int) -> SpriteSheet? {
        let w = image.width
        let h = image.height
        let count = max(1, n)
        let fw = w / count
        // A little-endian premultiplied ARGB word is B,G,R,A in memory. Alpha stays at byte 3.
        let bgra = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard fw > 0, h > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: space, bitmapInfo: bgra)
        else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let decoded = ctx.makeImage(), let data = ctx.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        // Union of the visible rows and columns over all frames, in frame-local pixels (row 0 is the top).
        var minX = fw, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            let row = y * w * 4
            var rowHit = false
            for x in 0..<w where pixels[row + x * 4 + 3] > 2 {
                let lx = x % fw
                if lx < minX { minX = lx }
                if lx > maxX { maxX = lx }
                rowHit = true
            }
            if rowHit {
                if y < minY { minY = y }
                maxY = y
            }
        }
        if maxX < minX || maxY < minY { minX = 0; maxX = fw - 1; minY = 0; maxY = h - 1 }
        // A little air so filtering at the edges stays soft.
        minX = max(0, minX - 2); minY = max(0, minY - 2)
        maxX = min(fw - 1, maxX + 2); maxY = min(h - 1, maxY + 2)
        let bw = maxX - minX + 1
        let bh = maxY - minY + 1
        var out: [CGImage] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            guard let part = decoded.cropping(to: CGRect(x: i * fw + minX, y: minY, width: bw, height: bh)),
                  let fctx = CGContext(data: nil, width: bw, height: bh, bitsPerComponent: 8, bytesPerRow: bw * 4,
                                       space: space, bitmapInfo: bgra)
            else { return nil }
            fctx.draw(part, in: CGRect(x: 0, y: 0, width: bw, height: bh))
            guard let frame = fctx.makeImage() else { return nil }
            out.append(frame)
        }
        let crop = CGRect(x: CGFloat(minX) / CGFloat(fw), y: CGFloat(minY) / CGFloat(h),
                          width: CGFloat(bw) / CGFloat(fw), height: CGFloat(bh) / CGFloat(h))
        return SpriteSheet(frames: out, crop: crop)
    }
}

extension SceneArt {
    /// The newest quarter the operation sells in: its house stands across the street.
    static func newestQuarter(_ s: FlowState) -> Quarter { Quarter.allCases.last { s.quarters[$0] != nil } ?? .cellars }

    /// What the scene shows for this state, and the next look of each floor, to decode before it is needed.
    static func prewarmList(_ s: FlowState) -> [(name: String, frames: Int)] {
        var list: [(name: String, frames: Int)] = [("SkyNight", 1), ("SkylineFar", 1), ("SkylineNear", 1), ("Street", 1), ("ShaftTile", 1),
                                     ("Foundation", 1), ("StreetLampGlow", 1), ("StreetLamp", 1), ("LiftCarEmpty", 1),
                                     ("LiftCarLoaded", 1), ("LiftHead", 1), ("Fireflies8", 8), ("CoinBurst8", 8), ("DustPuff6", 6),
                                     ("TapHand4", 4), ("ShelfFrame", 1), ("CopWalk8", 8), ("CopNotebook4", 4), ("SirenGlow4", 4),
                                     ("PoliceSiren2", 2), ("PoliceCarBody", 1), ("PoliceCarWheel", 1), ("Moon", 1)]
        for g in s.openGoods {
            let level = s.workshop(g)?.bench ?? 1
            let next = [10, 25, 50, 100, 200].first { $0 > level } ?? level
            for l in Set([level, next]) {
                list += [(floor(g, level: l), 1), (floorLit(g, level: l), 1), (floorRun(g, level: l), 4)]
            }
            list += [(worker(g, .walk), 8), (worker(g, .carry), 8), (worker(g, .work), 4), (worker(g, .sleep), 2),
                     (body(FlowContent.good(g).lead), 2), (talk(FlowContent.good(g).lead), 4)]
        }
        if let locked = Good.allCases.first(where: { !s.isOpen($0) }) { list.append((floorLocked(locked), 1)) }
        let v = vehicle(fleetLevel: s.fleet)
        list.append((v.body, 1))
        if let wheel = v.wheel { list.append((wheel, 1)) } else { list.append(("Fleet0Push8", 8)) }
        list.append((depot(fleetLevel: s.fleet), 1))
        let quarter = newestQuarter(s)
        list += [(customers(quarter, hot: false), 1), (customers(quarter, hot: true), 1), (buyer(quarter, walking: false), 2),
                 ("Buyer\(name(quarter))Carry8", 8)]
        list += [(body(FlowContent.dispatcher), 2), (talk(FlowContent.dispatcher), 4), ("BodyVargaWhistle4", 4)]
        return list
    }
}
