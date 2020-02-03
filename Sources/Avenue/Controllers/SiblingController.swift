import Foundation
import FluentPostgreSQL
import Vapor

public struct SiblingController<LHS: VaporSibling, RHS: VaporModel, Pivot: VaporPivot> {
    var keypathLeft: WritableKeyPath<Pivot, Int>
    var keypathRight: WritableKeyPath<Pivot, Int>
    
    // MARK: Boot
    public init(router: Router, keypathLeft: WritableKeyPath<Pivot, Int>, keypathRight: WritableKeyPath<Pivot, Int>) {
        self.keypathLeft = keypathLeft
        self.keypathRight = keypathRight
        print("🚀🚀🚀 Adding routes for siblings LHS: \(LHS.name) and RHS: \(RHS.name)")
        let lhsName = LHS.name.lowercased()
        let rhsName = RHS.name.lowercased()
        let route = router.grouped(lhsName)
        route.post(LHS.parameter, "\(rhsName)", RHS.parameter, "attach", use: add)
        route.delete(LHS.parameter, "\(rhsName)", RHS.parameter, "detach", use: remove)
        route.get(LHS.parameter, "siblings", "\(rhsName)", use: getAllLHS)
        let routeRHS = router.grouped(rhsName)
        routeRHS.get(RHS.parameter, "siblings", "\(lhsName)", use: getAllRHS)
    }
    
    
    //MARK: Main
    func add(_ req: Request) throws -> Future<HTTPStatus> {
        guard let ownerId = req.http.headers.firstValue(name: .contentID) else { throw Abort(.unauthorized) }
        return flatMap((try req.parameters.next(LHS.self) as! EventLoopFuture<LHS>), (try req.parameters.next(RHS.self) as! EventLoopFuture<RHS>)) { (lhs, rhs) -> Future<HTTPStatus> in
            guard lhs.ownerID == nil || lhs.ownerID?.contains(ownerId) ?? false, rhs.ownerID == nil || rhs.ownerID?.contains(ownerId) ?? false else { throw Abort(.forbidden) }
            return lhs.isAttached(rhs, on: req).map({ isAttached -> EventLoopFuture<Pivot?>? in
                if isAttached { return nil }
                return lhs.attach(rhs, on: req)
            }).transform(to: .created)
        }
    }
    
    func remove(_ req: Request) throws -> Future<HTTPResponseStatus> {
        guard let ownerId = req.http.headers.firstValue(name: .contentID) else { throw Abort(.unauthorized) }
        return flatMap(try req.parameters.next(LHS.self) as! EventLoopFuture<LHS>, try req.parameters.next(RHS.self) as! EventLoopFuture<RHS>) { (lhs, rhs) -> Future<HTTPResponseStatus> in
            guard lhs.ownerID == nil || lhs.ownerID?.contains(ownerId) ?? false, rhs.ownerID == nil || rhs.ownerID?.contains(ownerId) ?? false else { throw Abort(.forbidden) }
            return lhs.detach(rhs, on: req).transform(to: .ok)
        }
    }
    
    func getAllLHS(_ req: Request) throws -> Future<[RHS]> {
        return (try req.parameters.next(LHS.self) as! EventLoopFuture<LHS>).flatMap { lhs -> EventLoopFuture<[RHS]> in
            return RHS.applyQuery(req, try lhs.siblings(related: RHS.self, through: Pivot.self, self.keypathLeft, self.keypathRight).query(on: req)).all()
        }
    }
    
    func getAllRHS(_ req: Request) throws -> Future<[LHS]> {
        return (try req.parameters.next(RHS.self) as! EventLoopFuture<RHS>).flatMap { rhs -> EventLoopFuture<[LHS]> in
            return LHS.applyQuery(req, try rhs.siblings(related: LHS.self, through: Pivot.self, self.keypathRight, self.keypathLeft).query(on: req)).all()
        }
    }
}
