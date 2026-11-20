import CoreGraphics
import Foundation
import Testing
@testable import NoirLedger

@Suite("Sprite bitmap decoding")
struct SpriteDecodeTests {
    @Test("Frames keep a common crop and premultiplied BGRA bytes")
    func frameLayout() throws {
        // Two 12x9 frames: black tests alpha-only trimming, semi-transparent blue tests premultiplication.
        let width = 24, height = 9
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        func put(_ x: Int, _ pixel: [UInt8]) {
            let i = (4 * width + x) * 4
            rgba.replaceSubrange(i..<(i + 4), with: pixel)
        }
        put(3, [0, 0, 0, 255]); put(5, [255, 0, 0, 255]); put(12 + 8, [0, 0, 255, 128])
        let provider = try #require(CGDataProvider(data: Data(rgba) as CFData))
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let format = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
        let source = try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                          bytesPerRow: width * 4, space: space, bitmapInfo: format, provider: provider,
                                          decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let sheet = try #require(SceneImages.make(source, frames: 2))
        #expect(sheet.frames.count == 2)
        #expect(sheet.crop == CGRect(x: 1.0 / 12, y: 2.0 / 9, width: 10.0 / 12, height: 5.0 / 9))
        for frame in sheet.frames {
            #expect(frame.alphaInfo == .premultipliedFirst)
            #expect(frame.bitmapInfo.contains(.byteOrder32Little))
            #expect(frame.width == 10 && frame.height == 5 && frame.bitsPerPixel == 32)
        }
        func pixel(_ i: Int, _ x: Int) throws -> [UInt8] {
            let frame = sheet.frames[i]
            let data = try #require(frame.dataProvider?.data)
            let offset = 2 * frame.bytesPerRow + x * 4
            return Array((data as Data)[offset..<(offset + 4)])
        }
        let black = try pixel(0, 2), red = try pixel(0, 4), blue = try pixel(1, 7), blank = try pixel(1, 2)
        #expect(black == [0, 0, 0, 255]); #expect(red == [0, 0, 255, 255])
        #expect(blue == [128, 0, 0, 128]); #expect(blank == [0, 0, 0, 0])
    }
}
