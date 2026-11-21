import Testing
@testable import NoirLedger

@Suite("Opening timestamps use only app events")
struct OpeningStampsTests {
    @Test func excludesOnlyResponsiveInputWait() throws {
        var s = OpeningStamps()
        s.frame(.offer, at: 90, visible: true) // Wrong screen: must not start this stamp.
        s.frame(.door, at: 100, visible: true); s.touch(.door, at: 102)
        s.frame(.receipt, at: 103, visible: true); s.frame(.receipt, at: 104, visible: true)
        s.frame(.heirloom, at: 103, visible: true); s.touch(.heirloom, at: 106)
        s.frame(.offer, at: 108, visible: true)
        for tick in 1...600 { s.frame(.offer, at: 108 + Double(tick) / 10, visible: true) }
        s.frame(.offer, at: 172, visible: true) // Main-loop stall stays in the adjusted time.
        s.frame(.offer, at: 172.05, visible: false)
        s.frame(.offer, at: 172.09, visible: true) // Reappearance does not bridge the offscreen interval.
        s.touch(.offer, at: 173); s.touch(.offer, at: 174)
        s.frame(.confirm, at: 174, visible: true); s.touch(.confirm, at: 175)
        #expect(s.report() == nil)
        s.purchase(at: 176); s.purchase(at: 195)
        let report = try #require(s.report())
        #expect(report["interactive"] == 100 && report["receiptRaw"] == 3 && report["offerRaw"] == 8)
        #expect(report["robot"] == 60 && report["upgradeRaw"] == 76 && report["upgrade"] == 16)
        #expect(report["confirmed"] == 176 && report["offerTap"] == 173)
    }

    @Test func missingOrInvisibleEventsCannotPass() {
        var s = OpeningStamps()
        s.frame(.door, at: 10, visible: false); s.touch(.door, at: 12)
        s.frame(.receipt, at: 13, visible: true); s.touch(.heirloom, at: 14)
        s.frame(.offer, at: 15, visible: true); s.touch(.offer, at: 16); s.touch(.confirm, at: 17)
        s.purchase(at: 18)
        #expect(s.report() == nil && s.shown[.door] == nil && s.shown[.confirm] == nil)
    }
}
