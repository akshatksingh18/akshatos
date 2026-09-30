import Foundation
import SwiftData

@MainActor protocol BodyLogRepository {
    func load() throws -> BodyLogSnapshot
    func save(_ weight: BodyWeightEntry) throws
    func save(_ measurement: BodyMeasurement) throws
    func save(_ photo: BodyPhoto) throws
    func delete(id: UUID) throws
    func replaceAll(with snapshot: BodyLogSnapshot) throws
}

@MainActor final class SwiftDataBodyLogRepository: BodyLogRepository {
    private enum Kind {
        static let weight = "weight"
        static let measurement = "measurement"
        static let photo = "photo"
    }

    private var container: ModelContainer?

    init(container: ModelContainer? = nil) { self.container = container }

    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: BodyLogSchemaV1.self)
            container = try ModelContainer(for: schema, migrationPlan: BodyLogMigration.self,
                configurations: [ModelConfiguration("BodyLog", schema: schema)])
        }
        return container!.mainContext
    }

    /// A record that cannot be decoded fails the load rather than being dropped, so a damaged
    /// store is reported instead of silently shrinking your history.
    func load() throws -> BodyLogSnapshot {
        let decoder = JSONDecoder()
        var snapshot = BodyLogSnapshot()
        for row in try context().fetch(FetchDescriptor<BodyLogSchemaV1.SavedRecord>()) {
            switch row.kind {
            case Kind.weight: snapshot.weights.append(try decoder.decode(BodyWeightEntry.self, from: row.payload))
            case Kind.measurement:
                snapshot.measurements.append(try decoder.decode(BodyMeasurement.self, from: row.payload))
            case Kind.photo: snapshot.photos.append(try decoder.decode(BodyPhoto.self, from: row.payload))
            default: continue
            }
        }
        snapshot.weights.sort { $0.day > $1.day }
        snapshot.measurements.sort { ($0.day, $0.recordedAt) > ($1.day, $1.recordedAt) }
        snapshot.photos.sort { ($0.day, $0.recordedAt) > ($1.day, $1.recordedAt) }
        return snapshot
    }

    func save(_ weight: BodyWeightEntry) throws {
        try upsert(id: weight.id, kind: Kind.weight, payload: JSONEncoder().encode(weight))
    }

    func save(_ measurement: BodyMeasurement) throws {
        try upsert(id: measurement.id, kind: Kind.measurement, payload: JSONEncoder().encode(measurement))
    }

    func save(_ photo: BodyPhoto) throws {
        try upsert(id: photo.id, kind: Kind.photo, payload: JSONEncoder().encode(photo))
    }

    func delete(id: UUID) throws {
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<BodyLogSchemaV1.SavedRecord>()) where row.id == id {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func replaceAll(with snapshot: BodyLogSnapshot) throws {
        let context = try context()
        let encoder = JSONEncoder()
        do {
            for row in try context.fetch(FetchDescriptor<BodyLogSchemaV1.SavedRecord>()) {
                context.delete(row)
            }
            for weight in snapshot.weights {
                context.insert(BodyLogSchemaV1.SavedRecord(id: weight.id, kind: Kind.weight,
                                                           payload: try encoder.encode(weight)))
            }
            for measurement in snapshot.measurements {
                context.insert(BodyLogSchemaV1.SavedRecord(id: measurement.id, kind: Kind.measurement,
                                                           payload: try encoder.encode(measurement)))
            }
            for photo in snapshot.photos {
                context.insert(BodyLogSchemaV1.SavedRecord(id: photo.id, kind: Kind.photo,
                                                           payload: try encoder.encode(photo)))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func upsert(id: UUID, kind: String, payload: Data) throws {
        let context = try context()
        do {
            let rows = try context.fetch(FetchDescriptor<BodyLogSchemaV1.SavedRecord>())
            if let row = rows.first(where: { $0.id == id }) {
                row.kind = kind
                row.payload = payload
            } else {
                context.insert(BodyLogSchemaV1.SavedRecord(id: id, kind: kind, payload: payload))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
