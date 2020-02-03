import Foundation
import FluentPostgreSQL
import Vapor
@testable import Avenue

final class Event: VaporModel {
    static var createdAtKey: TimestampKey? { return \.createdAt }
    static var updatedAtKey: TimestampKey? { return \.updatedAt }
    
    var id: Int?
    var vendorID: Vendor.ID!
    var createdAt: Date?
    var updatedAt: Date?
    
    var title: String?
    var description: String?
    var startTime: Date?
    var endTime: Date?
    
    init(id: Int? = nil, vendorID: Vendor.ID? = nil) {
        self.id = id
        self.vendorID = vendorID
    }
    
    func update(_ model: Event) throws {
        title = model.title
        description = model.description
        startTime = model.startTime
        endTime = model.endTime
    }
}

extension Event {
    var vendor: Parent<Event, Vendor>? {
        return parent(\.vendorID)
    }
}

extension Event: Migration {
    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return PostgreSQLDatabase.create(Event.self, on: conn) { builder in
            builder.field(for: \.id, isIdentifier: true)
            builder.field(for: \.vendorID)
            builder.field(for: \.createdAt)
            builder.field(for: \.updatedAt)
            
            builder.field(for: \.title)
            builder.field(for: \.description)
            builder.field(for: \.startTime)
            builder.field(for: \.endTime)
            
            builder.reference(from: \.vendorID, to: \Vendor.id, onDelete: .cascade)
            builder.unique(on: \.id)
        }
    }
}
