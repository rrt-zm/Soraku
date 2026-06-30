import Foundation
import SwiftData

@Model
final class SaveRecord {
    @Attribute(.unique) var key: String
    var schemaVersion: Int
    var payload: Data
    var updatedAt: Date

    init(key: String, schemaVersion: Int, payload: Data, updatedAt: Date) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

protocol SnapshotPersistence {
    func load() -> GameSnapshot
    func save(_ snapshot: GameSnapshot)
}

final class SwiftDataPersistence: SnapshotPersistence {
    static let currentVersion = 2
    private let recordKey = "soraku.primary"
    private let container: ModelContainer?
    private let context: ModelContext?
    private let fileFallback: FileSnapshotPersistence

    init() {
        fileFallback = FileSnapshotPersistence()
        let schema = Schema([SaveRecord.self])
        let config = ModelConfiguration("Soraku", schema: schema, isStoredInMemoryOnly: false)
        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            container = c
            context = ModelContext(c)
        } else {
            container = nil
            context = nil
        }
    }

    func load() -> GameSnapshot {
        guard let context else { return fileFallback.load() }
        let descriptor = FetchDescriptor<SaveRecord>(predicate: #Predicate { $0.key == "soraku.primary" })
        if let record = try? context.fetch(descriptor).first {
            if let snapshot = decode(record.payload) {
                return migrate(snapshot)
            }
        }
        let fallback = fileFallback.load()
        return fallback
    }

    func save(_ snapshot: GameSnapshot) {
        fileFallback.save(snapshot)
        guard let context else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let descriptor = FetchDescriptor<SaveRecord>(predicate: #Predicate { $0.key == "soraku.primary" })
        if let record = try? context.fetch(descriptor).first {
            record.payload = data
            record.schemaVersion = snapshot.schemaVersion
            record.updatedAt = Date()
        } else {
            context.insert(SaveRecord(key: recordKey, schemaVersion: snapshot.schemaVersion, payload: data, updatedAt: Date()))
        }
        try? context.save()
    }

    private func decode(_ data: Data) -> GameSnapshot? {
        try? JSONDecoder().decode(GameSnapshot.self, from: data)
    }

    private func migrate(_ snapshot: GameSnapshot) -> GameSnapshot {
        var s = snapshot
        if s.schemaVersion < Self.currentVersion {
            s.schemaVersion = Self.currentVersion
        }
        return s
    }
}

final class FileSnapshotPersistence: SnapshotPersistence {
    private var url: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("soraku_snapshot.json")
    }

    func load() -> GameSnapshot {
        guard let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data) else {
            return GameSnapshot()
        }
        return snapshot
    }

    func save(_ snapshot: GameSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
