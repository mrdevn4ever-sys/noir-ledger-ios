import Foundation

/// Crash-safe local save file.
///
/// Writes go to a temporary file first. The previous primary file becomes the backup only if it still decodes,
/// then the temporary file atomically replaces the primary. Loading falls back to the backup when the primary is
/// missing or damaged, and a save written by a newer app version is never overwritten silently.
public struct SaveStore: Sendable {
    public enum LoadResult: Sendable {
        case fresh
        case loaded(GameState, restoredFromBackup: Bool, savedAtMs: Int64?)
        case futureVersion(Int)
    }

    public static let primaryName = "noir_ledger.save"
    public static let backupName = "noir_ledger.save.bak"
    public static let tempName = "noir_ledger.save.tmp"

    public let directory: URL
    public let codec: SaveCodec

    public var primaryURL: URL { directory.appendingPathComponent(Self.primaryName) }
    public var backupURL: URL { directory.appendingPathComponent(Self.backupName) }
    public var tempURL: URL { directory.appendingPathComponent(Self.tempName) }

    public init(directory: URL, codec: SaveCodec = SaveCodec()) {
        self.directory = directory
        self.codec = codec
    }

    /// `Application Support/NoirLedger`, created on demand.
    public static func defaultDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("NoirLedger", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func read(_ url: URL) -> SaveCodec.Decoded? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return .corrupt("io") }
        return codec.decode(data)
    }

    public func load() -> LoadResult {
        let primary = read(primaryURL)
        switch primary {
        case .some(.ok(let state, _)):
            return .loaded(state, restoredFromBackup: false, savedAtMs: savedAt(primaryURL))
        case .some(.futureVersion(let v)):
            return .futureVersion(v)
        case .some(.corrupt), .none:
            break
        }
        switch read(backupURL) {
        case .some(.ok(let state, _)):
            return .loaded(state, restoredFromBackup: primary != nil, savedAtMs: savedAt(backupURL))
        case .some(.futureVersion(let v)):
            return .futureVersion(v)
        case .some(.corrupt), .none:
            return .fresh
        }
    }

    private func savedAt(_ url: URL) -> Int64? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return codec.savedAt(data)
    }

    public func write(_ state: GameState, savedAtMs: Int64) throws {
        try write(data: codec.encode(state, savedAtMs: savedAtMs))
    }

    public func write(data: Data) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: tempURL, options: [.atomic])
        if fm.fileExists(atPath: primaryURL.path) {
            // Keep the last good save as backup only if it still decodes.
            if case .some(.ok) = read(primaryURL) {
                if fm.fileExists(atPath: backupURL.path) { try fm.removeItem(at: backupURL) }
                try fm.moveItem(at: primaryURL, to: backupURL)
            } else {
                try fm.removeItem(at: primaryURL)
            }
        }
        try fm.moveItem(at: tempURL, to: primaryURL)
    }

    public func erase() {
        let fm = FileManager.default
        for url in [primaryURL, backupURL, tempURL] where fm.fileExists(atPath: url.path) {
            try? fm.removeItem(at: url)
        }
    }

    public func lastSavedAt() -> Int64? { savedAt(primaryURL) }
}
