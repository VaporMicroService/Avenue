import Foundation
import Vapor
import XCTest
import FluentPostgreSQL
@testable import Avenue

extension List {
    static func create(vendorID: Vendor.ID,on connection: PostgreSQLConnection) throws -> List {
        let list = List(vendorID: vendorID)
        list.name = "Example List"
        list.description = "List with exmaple products"
        return try list.save(on: connection).wait()
    }
}

extension Product {
    static func create(vendorID: Vendor.ID, on connection: PostgreSQLConnection) throws -> Product {
        let product = Product(vendorID: vendorID)
        product.name = "Test Product"
        product.description = "None existend item"
        product.alcohol = 0.7
        return try product.save(on: connection).wait()
    }
}

class SiblingControllerTests: XCTestCase {
    static let allTests = [
        ("testAddSibling", testAddSibling),
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
    
    func testAddSibling() throws {
        let vendor = try Vendor.create(on: conn)
        let product = try Product.create(vendorID: try vendor.requireID(), on: conn)
        let list = try List.create(vendorID: try vendor.requireID(), on: conn)
        
        XCTAssertNil(try ListProduct.query(on: conn).filter(\ListProduct.productID ==  product.requireID()).filter(\ListProduct.listID ==  list.requireID()).first().wait())
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(List.name.lowercased())/\(list.id!)/\(Product.name.lowercased())/\(product.id!)/attach", method: .POST, headers: headers)
        XCTAssertEqual(response.http.status.code, 201)
        print(try ListProduct.query(on: conn).all().wait())
        XCTAssertNotNil(try ListProduct.query(on: conn).filter(\ListProduct.productID ==  product.requireID()).filter(\ListProduct.listID ==  list.requireID()).first().wait())
    }
    
    func testRemoveSibling() throws {
        let vendor = try Vendor.create(on: conn)
        let product = try Product.create(vendorID: try vendor.requireID(), on: conn)
        let list = try List.create(vendorID: try vendor.requireID(), on: conn)
        
        let event: EventLoopFuture<ListProduct?> = list.attach(product, on: conn)
        _ = try event.wait()
        
        XCTAssertNotNil(try ListProduct.query(on: conn).filter(\ListProduct.productID ==  product.requireID()).filter(\ListProduct.listID ==  list.requireID()).first().wait())
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(List.name.lowercased())/\(list.id!)/\(Product.name.lowercased())/\(product.id!)/detach", method: .DELETE, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        XCTAssertNil(try ListProduct.query(on: conn).filter(\ListProduct.productID ==  product.requireID()).filter(\ListProduct.listID ==  list.requireID()).first().wait())
    }
    
    func testGetLHSSibling() throws {
        let vendor = try Vendor.create(on: conn)
        let list = try List.create(vendorID: try vendor.requireID(), on: conn)
        
        for _ in 0..<50 {
            let product = try Product.create(vendorID: try vendor.requireID(), on: conn)
            let event: EventLoopFuture<ListProduct?> = list.attach(product, on: conn)
            _ = try event.wait()
        }
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(List.name.lowercased())/\(list.id!)/siblings/\(Product.name.lowercased())", method: .GET, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        let fetch = try response.content.syncDecode([Product].self)
        XCTAssert(fetch.count == 50)
        XCTAssertNotNil(fetch)
    }
    
    func testGetRHSSibling() throws {
        let vendor = try Vendor.create(on: conn)
        let product = try Product.create(vendorID: try vendor.requireID(), on: conn)
        
        for _ in 0..<25 {
            let list = try List.create(vendorID: try vendor.requireID(), on: conn)
            let event: EventLoopFuture<ListProduct?> = list.attach(product, on: conn)
            _ = try event.wait()
        }
        
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .contentID, value: "1234")
        let response = try app.sendRequest(to: "\(Product.name.lowercased())/\(product.id!)/siblings/\(List.name.lowercased())", method: .GET, headers: headers)
        XCTAssertEqual(response.http.status.code, 200)
        let fetch = try response.content.syncDecode([List].self)
        XCTAssert(fetch.count == 25)
        XCTAssertNotNil(fetch)
    }
}
