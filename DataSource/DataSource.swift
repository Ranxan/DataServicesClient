//
//  DataSourceFactory.swift
//  NetworkCaller
//
//  Created by Ranxan Adhikari on 8/9/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import RxSwift
import RealmSwift

public class DatasourceWithBaseResponse<I, O:Decodable>: GeneratorExtender<I, O, NetworkDataSource<I>> {
    public init(withPath path: String, HTTPMethod method: Method, sessionType type: SessionType = .defaultConfig, requestType: RequestType = .urlEncodedRequest) {
        let defaultParser: ParserClosure<Data, O> = { output in
            return output.asObservable().parseJsonToBaseResponse(withResponseType: O.self).asSingle()
        }
        super.init(withBaseGenerator: NetworkDataSource(path, method,type, BaseUrl.AppBaseUrl, requestType), outputParser: defaultParser)
    }
}

public class ThirdPartyClientsDataSource<I, O: Decodable>: GeneratorExtender<I, O, NetworkDataSource<I>>  {
    public init(withPath path: String, HTTPMethod method: Method, sessionType type: SessionType = .defaultConfig, requestType: RequestType = .urlEncodedRequest) {
        let defaultParser: ParserClosure<Data, O> = { output in
            return output.asObservable().parsefromJson(toModelType: O.self).asSingle()
        }
        super.init(withBaseGenerator: NetworkDataSource(path, method,type, path, requestType), outputParser: defaultParser)
    }
}

public class DatabaseDataSrc<I>: GeneratorExtender<I,NSObject, DatabaseDataSource<I>> {
    let defaultParser: ParserClosure<NSObject, NSObject> = { output in
        return output.asObservable().parsefromObject().asSingle()
    }
    
    public init(withDataBaseOperation dataBaseOperation: DataBaseOperation, databaseManger: DataBaseManager<NSObject>) {
        super.init(withBaseGenerator: DatabaseDataSource(withDataBaseOperation: dataBaseOperation, databaseManager: databaseManger), outputParser: defaultParser)
    }
}
