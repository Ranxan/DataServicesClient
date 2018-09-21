//
//  RealmServices.swift
//  4Service
//
//  Created by Nutan on 14/11/2017.
//  Copyright © 2017 SMS-DEV-ANISH. All rights reserved.
//

import Foundation
import RxSwift
import RealmSwift

public protocol DataBaseOperations {
    associatedtype I
    func insert(object obj: I) -> Single<I>
    func getObject(ofType type: I.Type) -> Single<I>
    func update(object obj: I) -> Single<I>
    func delete(object obj: I) -> Single<I>
}

public class DataBaseManager<I:NSObject>: DataBaseOperations {
    private let _insert: (_ object: I) -> Single<I>
    private let _update: (_ object: I) -> Single<I>
    private let _delete: (_ object: I) -> Single<I>
    private let _getObject: (_ type: I.Type) -> Single<I>
    
    public init<T: DataBaseOperations>(dbManager: T) where T.I == I {
        _insert = dbManager.insert
        _update = dbManager.update
        _delete = dbManager.delete
        _getObject = dbManager.getObject
    }
    
    public func insert(object obj: I) -> Single<I> {
        return _insert(obj)
    }
    
    public func getObject(ofType type: I.Type) -> Single<I> {
        return _getObject(type)
    }
    
    public func update(object obj: I) -> Single<I>{
        return _update(obj)
    }
    
    public func delete(object obj: I) -> Single<I>{
        return _delete(obj)
    }
}
