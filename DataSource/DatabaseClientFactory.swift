//
//  DatabaseClientFactory.swift
//  NetworkCaller
//
//  Created by Nutan Niraula on 8/20/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import RxSwift
import RealmSwift

public protocol DatabaseManagerFactoryProtocol {
    func getDatabaseManager(withManager manager: DataBaseManager<NSObject>) -> DataBaseManager<NSObject>
}

public class DatabaseManagerFactory : DatabaseManagerFactoryProtocol {
  
    static var databaseManagerFactory: DatabaseManagerFactory?
    
    public init() {}
    
    deinit {
        print("Deinit DatabaseManagerFactory")
    }
    
    public class func setFactory(clientFactory: DatabaseManagerFactory) {
        DatabaseManagerFactory.databaseManagerFactory = clientFactory
    }
    
    public class func getFactory() -> DatabaseManagerFactory {
        if(DatabaseManagerFactory.databaseManagerFactory==nil){
            DatabaseManagerFactory.databaseManagerFactory = DatabaseManagerFactory()
        }
        return DatabaseManagerFactory.databaseManagerFactory!
    }
    
    public func getDatabaseManager(withManager manager: DataBaseManager<NSObject>) -> DataBaseManager<NSObject> {
        return manager
    }
}
