import Foundation
import Vapor
import XCTest
import FluentPostgreSQL
@testable import Avenue

extension Event {
    static func create(vendorID: Vendor.ID,on connection: PostgreSQLConnection, title: String? = nil) throws -> Event {
        let event = Event(vendorID: vendorID)
        event.title = title
        return try event.save(on: connection).wait()
    }
}

class ChildControllerTests: XCTestCase {
    static let allTests = [
        ("testAddChild", testAddChild),
        ("testAddChildWithNoVendorId", testAddChildWithNoVendorId),
        ("testAddChildWithDifferentVendorIdInBody", testAddChildWithDifferentVendorIdInBody),
        ("testRemoveChild", testRemoveChild),
        ("testGetParent", testGetParent),
        ("testGetChild", testGetChild),
        ("testGetChildren", testGetChildren),
        ("testGetChildrenWithPagination", testGetChildrenWithPagination),
        ("testGetChildrenWithFilters", testGetChildrenWithFilters),
    ]
    
    var app: Application!
    var conn: PostgreSQLConnection!
    
    override func setUp() {
        try! Application.reset()
        app = try! Application.testable()
        conn = try! app.newConnection(to: .psql).wait()
    }
    
    override func tearDown() {
        conn.close()
        try? app.syncShutdownGracefully()
    }
    
    func testAddChild() throws {
        let vendor = try Vendor.create(on: conn)
        let event = Event(vendorID: try vendor.requireID())
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/add", method: .PUT, headers: headers, body: event)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode(Event.self)
        XCTAssertNotNil(fetch.id)
        XCTAssertNotNil(fetch)
        XCTAssertNotNil(try vendor.events.query(on: conn).filter(\.id == fetch.id!).first().wait())
    }
    
    func testAddChildWithNoVendorId() throws {
        let vendor = try Vendor.create(on: conn)
        let event = Event()
        event.title = "Test Event"
        event.description = "description for tests"
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/add", method: .PUT, headers: headers, body: event)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode(Event.self)
        XCTAssertNotNil(fetch.id)
        XCTAssertNotNil(fetch)
        XCTAssertNotNil(try vendor.events.query(on: conn).filter(\.id == fetch.id!).first().wait())
    }
    
    func testAddChildWithDifferentVendorIdInBody() throws {
        let vendor = try Vendor.create(on: conn)
        let event = Event(vendorID: 9876543221)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/add", method: .PUT, headers: headers, body: event)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode(Event.self)
        XCTAssertNotNil(fetch.id)
        XCTAssertNotNil(fetch)
        XCTAssertNotNil(try vendor.events.query(on: conn).filter(\.id == fetch.id!).first().wait())
    }
    
    func testRemoveChild() throws {
        let vendor = try Vendor.create(on: conn)
        let event = try Event.create(vendorID: try vendor.requireID(), on: conn)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/\(event.id!)/remove", method: .DELETE, headers: headers)
        XCTAssertEqual(response.http.status.code, 204)
    }
    
    func testGetParent() throws {
        let vendor = try Vendor.create(on: conn)
        let event = try Event.create(vendorID: try vendor.requireID(), on: conn)
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Vendor.name.lowercased())/\(Event.name.lowercased())/\(event.id!)/parent", method: .GET, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode(Vendor.self)
        XCTAssert(try fetch.id == vendor.requireID())
        XCTAssertNotNil(fetch)
    }
    
    func testGetChild() throws {
        let vendor = try Vendor.create(on: conn)
        let event = try Event.create(vendorID: try vendor.requireID(), on: conn)

        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/\(event.id!)", method: .GET, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode(Event.self)
        XCTAssert(try fetch.id == event.requireID())
        XCTAssertNotNil(fetch)
    }
    
    func testGetChildren() throws {
        let vendor = try Vendor.create(on: conn)
        for _ in 0 ..< 75 {
            _ = try Event.create(vendorID: try vendor.requireID(), on: conn)
        }
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/children", method: .GET, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode([Event].self)
        XCTAssert(fetch.count == 75)
        XCTAssertNotNil(fetch)
    }
    
    func testGetChildrenWithPagination() throws {
        let vendor = try Vendor.create(on: conn)
        for _ in 0 ..< 100 {
            _ = try Event.create(vendorID: try vendor.requireID(), on: conn)
        }
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let url = "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/children?offset[length]=12&offset[index]=18"
        let response = try app.sendRequest(to: url, method: .GET, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode([Event].self)
        XCTAssert(fetch.count == 12)
        XCTAssertNotNil(fetch)
    }
    
    func testGetChildrenWithFilters() throws {
        let vendor = try Vendor.create(on: conn)
        for i in 0 ..< 100 {
            _ = try Event.create(vendorID: try vendor.requireID(), on: conn, title: i < 2 ? "Test Name" : nil)
        }
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let url = "\(Vendor.name.lowercased())/\(vendor.id!)/\(Event.name.lowercased())/children?where[1][key]=title&where[1][operator]==&where[1][value]=Test%20Name"

        let response = try app.sendRequest(to: url, method: .GET, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        
        let fetch = try response.content.syncDecode([Event].self)
        XCTAssert(fetch.count == 2)
        XCTAssertNotNil(fetch)
    }
}
