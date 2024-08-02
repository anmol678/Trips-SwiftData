//
//  JSONStore.swift
//  SampleTrips
//
//  Created by Anmol Jain on 8/1/24.
//  Copyright © 2024 Apple. All rights reserved.
//

import SwiftData
import Foundation

final class JSONStoreConfiguration: DataStoreConfiguration {
    typealias Store = JSONStore
  
    var name: String
    var schema: Schema?
    var fileURL: URL

    init(name: String, schema: Schema? = nil, fileURL: URL) {
        self.name = name
        self.schema = schema
        self.fileURL = fileURL
    }

    static func == (lhs: JSONStoreConfiguration, rhs: JSONStoreConfiguration) -> Bool {
        return lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

final class JSONStore: DataStore {
    typealias Configuration = JSONStoreConfiguration
    typealias Snapshot = DefaultSnapshot

    var configuration: JSONStoreConfiguration
    var name: String
    var schema: Schema
    var identifier: String

    init(_ configuration: JSONStoreConfiguration, migrationPlan: (any SchemaMigrationPlan.Type)?) throws {
        self.configuration = configuration
        self.name = configuration.name
        self.schema = configuration.schema!
        self.identifier = configuration.fileURL.lastPathComponent
    }

    func save(_ request: DataStoreSaveChangesRequest<DefaultSnapshot>) throws -> DataStoreSaveChangesResult<DefaultSnapshot> {
        var remappedIdentifiers = [PersistentIdentifier: PersistentIdentifier]()
        var serializedSnapshots = try self.read()

        for snapshot in request.inserted {
            let permanentIdentifier = try PersistentIdentifier.identifier(for: identifier,
                                                                          entityName: snapshot.persistentIdentifier.entityName,
                                                                          primaryKey: UUID())
            let permanentSnapshot = snapshot.copy(persistentIdentifier: permanentIdentifier)
            serializedSnapshots[permanentIdentifier] = permanentSnapshot
            remappedIdentifiers[snapshot.persistentIdentifier] = permanentIdentifier
        }

        for snapshot in request.updated {
            serializedSnapshots[snapshot.persistentIdentifier] = snapshot
        }

        for snapshot in request.deleted {
            serializedSnapshots[snapshot.persistentIdentifier] = nil
        }
        
        serializedSnapshots = serializedSnapshots.mapValues { snapshot in
            snapshot.copy(persistentIdentifier: snapshot.persistentIdentifier, remappedIdentifiers: remappedIdentifiers)
        }
      
        try self.write(serializedSnapshots)
        return DataStoreSaveChangesResult<DefaultSnapshot>(for: self.identifier, remappedIdentifiers: remappedIdentifiers)
    }

    func fetch<T>(_ request: DataStoreFetchRequest<T>) throws -> DataStoreFetchResult<T, DefaultSnapshot> where T : PersistentModel {
        if request.descriptor.predicate != nil {
            throw DataStoreError.preferInMemoryFilter
        } else if request.descriptor.sortBy.count > 0 {
            throw DataStoreError.preferInMemorySort
        }

        let objs = try self.read(entityName: String(describing: T.self))
        let snapshots = Array(objs.values)
        return DataStoreFetchResult(descriptor: request.descriptor, fetchedSnapshots: snapshots, relatedSnapshots: objs)
    }

    func read(entityName: String? = nil) throws -> [PersistentIdentifier: DefaultSnapshot] {
        guard FileManager.default.fileExists(atPath: configuration.fileURL.path(percentEncoded: false)) else {
            return [:]
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let snapshots = try decoder.decode([DefaultSnapshot].self, from: try Data(contentsOf: configuration.fileURL))
        return snapshots.reduce(into: [PersistentIdentifier: DefaultSnapshot]()) { result, snapshot in
            if entityName == nil || snapshot.persistentIdentifier.entityName == entityName {
                result[snapshot.persistentIdentifier] = snapshot
            }
        }
    }

    func write(_ snapshots: [PersistentIdentifier: DefaultSnapshot]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(snapshots.values.map({ $0 }))
        try jsonData.write(to: configuration.fileURL)
    }
}
