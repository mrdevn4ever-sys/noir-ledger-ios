import Foundation
import NoirCore
import Testing

@Suite("Save codec, migration and atomic store")
struct SaveTests {

    private func midGame() -> GameState {
        var s = TS.rich(chapter: 3)
        s = TS.ok(s, .hire("brandt"))
        s = TS.ok(s, .buyUpgrade(.bikeCouriers))
        s = TS.ok(s, .unlockDistrict(.docks))
        s.pendingEvent = PendingEvent(event: .rivalTruce, district: .docks, unit: 100, cleanUnit: 40, influenceUnit: 20, createdAt: s.time)
        s.investigation = Investigation(startedAt: 1, endsAt: 181, district: .docks)
        s.modifiers = [TimedModifier(kind: .demand, value: 1.4, until: s.time + 100, district: .neonMile)]
        s.legacy = LegacyState(ngLevel: 1, points: 7, perks: [.coldTrail: 2], wins: 1)
        s.rng = UInt64Box(0xFEDC_BA98_7654_3210)
        return s
    }

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("noir-save-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Encode → decode is lossless, including the full 64-bit random state")
    func roundTrip() throws {
        let codec = SaveCodec()
        let s = midGame()
        let data = try codec.encode(s, savedAtMs: 123_456)
        guard case .ok(let decoded, let migratedFrom) = codec.decode(data) else {
            Issue.record("decode failed")
            return
        }
        #expect(migratedFrom == nil)
        #expect(decoded == s)
        #expect(decoded.rng.raw == 0xFEDC_BA98_7654_3210)
        #expect(codec.savedAt(data) == 123_456)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"schema\":\(saveSchemaVersion)"))
    }

    @Test("Saves from a newer version are recognised and never decoded")
    func futureVersion() throws {
        let data = try SaveCodec(currentVersion: 5).encode(GameState(), savedAtMs: 1)
        guard case .futureVersion(let v) = SaveCodec().decode(data) else {
            Issue.record("expected future version")
            return
        }
        #expect(v == 5)
    }

    @Test("Damaged data is reported as corrupt", arguments: ["", "{", "[]", "{\"schema\":1}", "{\"schema\":0,\"state\":{}}", "{\"state\":{}}"])
    func corrupt(_ text: String) {
        guard case .corrupt = SaveCodec().decode(Data(text.utf8)) else {
            Issue.record("expected corrupt for \(text)")
            return
        }
    }

    @Test("Missing fields fall back to defaults and out-of-range values are repaired")
    func sanitize() throws {
        let json = """
        {"schema":1,"savedAt":5,"state":{"dirty":"nan","heat":250,"storageLevel":99,"reserveMinutes":7,
         "campaign":{"chapter":42,"prologueDone":true},
         "lines":{"GLIMMER":{"capacityLevel":0,"speedLevel":77}},
         "crew":[{"defId":"ghost","loyalty":50},{"defId":"brandt","loyalty":900}],
         "legacy":{"perks":{"KNOWN_NAME":9}}}}
        """
        guard case .ok(let s, _) = SaveCodec().decode(Data(json.utf8)) else {
            Issue.record("expected tolerant decode")
            return
        }
        #expect(s.dirty == 0)
        #expect(s.heat == 100)
        #expect(s.storageLevel == Content.maxStorageLevel)
        #expect(s.reserveMinutes == 2)
        #expect(s.campaign.chapter == Content.finalChapter)
        #expect(s.line(.glimmer).owned)
        #expect(s.line(.glimmer).capacityLevel == 1)
        #expect(s.line(.glimmer).speedLevel == Content.maxLineLevel)
        #expect(s.crew.map(\.defId) == ["brandt"])
        #expect(s.crew.first?.loyalty == 100)
        #expect(s.district(.cellars).unlocked)
        #expect(s.legacy.rank(.knownName) == 3)
        #expect(DistrictId.allCases.allSatisfy { s.districts[$0] != nil })
        #expect(FrontId.allCases.allSatisfy { s.fronts[$0] != nil })
        TS.expectSane(s)
    }

    @Test("Migrations run in order on the raw JSON before decoding")
    func migrationPipeline() throws {
        // A schema-1 save as written today, read by a hypothetical schema-3 app.
        let v1 = try SaveCodec(currentVersion: 1).encode(midGame(), savedAtMs: 9)
        let codec = SaveCodec(currentVersion: 3, migrations: [
            1: { obj in var o = obj; o["dirty"] = 42.0; return o },
            2: { obj in var o = obj; o["clean"] = 7.0; return o },
        ])
        guard case .ok(let s, let from) = codec.decode(v1) else {
            Issue.record("migration failed")
            return
        }
        #expect(from == 1)
        #expect(s.dirty == 42)
        #expect(s.clean == 7)
        #expect(s.version == 3)
        #expect(s.legacy.points == 7)
    }

    @Test("A missing or throwing migration marks the save corrupt instead of crashing")
    func brokenMigration() throws {
        let v1 = try SaveCodec(currentVersion: 1).encode(GameState(), savedAtMs: 1)
        guard case .corrupt = SaveCodec(currentVersion: 2, migrations: [:]).decode(v1) else {
            Issue.record("expected corrupt without migration")
            return
        }
        struct Boom: Error {}
        guard case .corrupt = SaveCodec(currentVersion: 2, migrations: [1: { _ in throw Boom() }]).decode(v1) else {
            Issue.record("expected corrupt when the migration throws")
            return
        }
    }

    @Test("The store writes atomically, keeps the previous good save as backup and loads it back")
    func storeRoundTrip() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        guard case .fresh = store.load() else {
            Issue.record("empty directory should be fresh")
            return
        }
        var s = midGame()
        try store.write(s, savedAtMs: 100)
        #expect(!FileManager.default.fileExists(atPath: store.backupURL.path))
        s.dirty = 999
        try store.write(s, savedAtMs: 200)
        #expect(FileManager.default.fileExists(atPath: store.backupURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.tempURL.path))
        guard case .loaded(let loaded, let restored, let savedAt) = store.load() else {
            Issue.record("expected loaded")
            return
        }
        #expect(loaded.dirty == 999)
        #expect(!restored)
        #expect(savedAt == 200)
        #expect(store.lastSavedAt() == 200)
    }

    @Test("A damaged primary file is recovered from the backup")
    func recoverFromBackup() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        var s = midGame()
        s.dirty = 111
        try store.write(s, savedAtMs: 1)
        s.dirty = 222
        try store.write(s, savedAtMs: 2)
        try Data("garbage".utf8).write(to: store.primaryURL)
        guard case .loaded(let loaded, let restored, _) = store.load() else {
            Issue.record("expected backup restore")
            return
        }
        #expect(restored)
        #expect(loaded.dirty == 111)
        // The next write replaces the damaged primary without promoting it to backup.
        try store.write(loaded, savedAtMs: 3)
        guard case .loaded(let again, let restoredAgain, _) = store.load() else {
            Issue.record("expected load")
            return
        }
        #expect(!restoredAgain)
        #expect(again.dirty == 111)
    }

    @Test("Both files damaged starts fresh; a newer-version save is reported, not overwritten by loading")
    func unrecoverableAndFuture() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        try Data("x".utf8).write(to: store.primaryURL)
        try Data("y".utf8).write(to: store.backupURL)
        guard case .fresh = store.load() else {
            Issue.record("expected fresh")
            return
        }
        let future = try SaveCodec(currentVersion: 9).encode(GameState(), savedAtMs: 1)
        try future.write(to: store.primaryURL)
        guard case .futureVersion(9) = store.load() else {
            Issue.record("expected future version")
            return
        }
        #expect(try Data(contentsOf: store.primaryURL) == future)
        store.erase()
        #expect(!FileManager.default.fileExists(atPath: store.primaryURL.path))
        #expect(!FileManager.default.fileExists(atPath: store.backupURL.path))
    }

    @Test("Interrupted write: a leftover temp file never replaces a good save")
    func interruptedWrite() throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        var s = midGame()
        s.dirty = 5
        try store.write(s, savedAtMs: 1)
        try Data("half-writt".utf8).write(to: store.tempURL)
        guard case .loaded(let loaded, false, _) = store.load() else {
            Issue.record("expected primary load")
            return
        }
        #expect(loaded.dirty == 5)
    }
}
