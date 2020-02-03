import Foundation
import FluentPostgreSQL
import Vapor

public struct ChildController<Parent: VaporModel, Child: VaporModel> {
    var keypath: KeyPath<Child, Int>
    
    // MARK: Boot
    public init(router: Router, keypath: KeyPath<Child, Int>) {
        self.keypath = keypath
        print("🚀🚀🚀 Adding routes for Prent: \(Parent.name) and Child: \(Child.name)")
        let parentName = Parent.name.lowercased()
        let childName = Child.name.lowercased()
        let route = router.grouped(parentName)
        route.put(Parent.parameter, "\(childName)", "add", use: addChild)
        route.delete(Parent.parameter, "\(childName)", Child.parameter, "remove", use: removeChild)
        route.get(Parent.parameter, "\(childName)", "children", use: getAllChildren)
        route.get(Parent.parameter, "\(childName)", Child.parameter, use: getChild)
        route.get("\(childName)", Child.parameter, "parent", use: getParent)
    }
    
    
    //MARK: Main
    func addChild(_ req: Request) throws -> Future<Child> {
        guard let ownerId = req.http.headers.firstValue(name: .contentID) else { throw Abort(.unauthorized) }
        return (try req.parameters.next(Parent.self) as! EventLoopFuture<Parent>).flatMap { (parent) -> EventLoopFuture<Child> in
            guard parent.ownerID?.contains(ownerId) ?? false else { throw Abort(.forbidden) }
            return try req.content.decode(Child.self, using: decoderJSON).flatMap { model in
                var newModel = model
                newModel.assignOwner(ownerId)
                return newModel.save(on: req)
            }
        }
    }
    
    func removeChild(_ req: Request) throws -> Future<HTTPResponseStatus> {
        guard let ownerId = req.http.headers.firstValue(name: .contentID) else { throw Abort(.unauthorized) }
        return flatMap(try req.parameters.next(Parent.self) as! EventLoopFuture<Parent>, try req.parameters.next(Child.self) as! EventLoopFuture<Child>) { parent, child -> Future<HTTPResponseStatus> in
            let acctualParent: Fluent.Parent<Child, Parent> = child.parent(self.keypath)
            guard try parent.requireID() == acctualParent.parentID else { throw Abort(.badRequest) }
            guard parent.ownerID?.contains(ownerId) ?? false else { throw Abort(.forbidden) }
            return child.delete(on: req).transform(to: HTTPStatus.noContent)
        }
    }
    
    func getAllChildren(_ req: Request) throws -> Future<[Child]> {
        return (try req.parameters.next(Parent.self) as! EventLoopFuture<Parent>).flatMap { parent -> EventLoopFuture<[Child]> in
            return Child.applyQuery(req, try parent.children(self.keypath).query(on: req)).all()
        }
    }
    
    func getChild(_ req: Request) throws -> Future<Child> {
        return map(try req.parameters.next(Parent.self) as! EventLoopFuture<Parent>, try req.parameters.next(Child.self) as! EventLoopFuture<Child>) { parent, child -> Child in
            let acctualParent: Fluent.Parent<Child, Parent> = child.parent(self.keypath)
            guard try parent.requireID() == acctualParent.parentID else { throw Abort(.badRequest) }
            return child
        }
    }
    
    func getParent(_ req: Request) throws -> Future<Parent> {
        return (try req.parameters.next(Child.self) as! EventLoopFuture<Child>).flatMap { child -> EventLoopFuture<Parent> in
            let parent: Fluent.Parent<Child, Parent> = child.parent(self.keypath)
            return parent.get(on: req)
        }
    }
}
