//
//  EndPoints.swift
//  NetworkCaller
//
//  Created by Gurung Bishow on 6/7/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import RxSwift
import RealmSwift

public typealias DataSourceClosure<I,O> = (I) -> Single<O>
public typealias ParserClosure<I, O> = (Single<I>) -> Single<O>
public typealias InputConverter<I,O> = (I) -> O

public protocol HeaderFetchable {
    var headerParameters:[String:String] {get set}
}

public protocol DataSourceGeneratable {
    associatedtype I
    associatedtype O
    func generate() -> DataSourceClosure<I,O>
    func generate<PO>(parser: @escaping ParserClosure<O, PO>) -> DataSourceClosure<I,PO>
}

func combineParser<I1,O1,O2>(_ parser1:@escaping (I1)->O1, _ parser2:@escaping (O1)->O2)->(I1)->O2 {
    return {(inp: I1) in
        return parser2(parser1(inp))
    }
}

public enum RequestType {
    case urlEncodedRequest
    case multipartUpload
}

open class GeneratorExtender<I,O, G: DataSourceGeneratable> : DataSourceGeneratable {
    let baseGenerator: G
    private let outputParser: ParserClosure<G.O, O>
    private let inputConverter: InputConverter<I, G.I>
    
    init(withBaseGenerator baseGenerator: G,
         outputParser parser: @escaping ParserClosure<G.O, O> ,
         inputConverter converter: @escaping InputConverter<I, G.I> = {(input:I) in
        return input as! G.I})
    {
        self.baseGenerator = baseGenerator
        self.outputParser = parser
        self.inputConverter = converter
    }
    
    public final func generate() -> DataSourceClosure<I, O> {
        return self.generate(parser: {outputClosure in return outputClosure})
    }
    
    public final func generate<PO>(parser: @escaping ParserClosure<O, PO>) -> DataSourceClosure<I,PO> {
        let clouser = self.baseGenerator.generate(parser: combineParser(outputParser, parser))
        let inputConverter = self.inputConverter
        return { (inp:I) in
            return clouser(inputConverter(inp))
        }
    }
}

public struct NetworkDataSource<I> : DataSourceGeneratable  {
    private var path: String!
    private var method: Method!
    private var baseUrl: String!
    private let sessionType:SessionType!
    private var requestType:RequestType!
    
    init(_ path: String, _ method: Method,_ type: SessionType, _ baseUrl: String, _ requestType: RequestType)  {
        self.path = path
        self.method = method
        self.baseUrl = baseUrl
        self.sessionType = type
        self.requestType = requestType
    }
    
    public func generate() -> DataSourceClosure<I,Data> {
        return self.generate(parser: { (outResponse) in
            return outResponse
        })
    }
    
    public func generate<PO>(parser: @escaping ParserClosure<Data, PO>) -> DataSourceClosure<I,PO> {
        return {(_ input: I) in
            let networkClient = NetworkClientFactory.getFactory().getNetworkClient(withSessionType: self.sessionType, baseUrl: self.baseUrl)
            let path = self.path.contains("{") ? self.composeDynamicPath(withInput: input, withPath: self.path) : self.path
            switch self.requestType! {
                
            case .urlEncodedRequest:
                let endpoint =  ((input as? Encodable) != nil) ? Endpoint(method: self.method, path: path!, parameters: input as! Encodable) : Endpoint(method: self.method, path: path!)
                let singleObservableOfData = networkClient.request(withEndpoint: endpoint).map({ (response) -> Data in
                    if PO.self is HeaderFetchable.Type {
                        let data = self.setHeader(fromResponse: response)
                        return data
                    }
                    return response.data
                })
                return parser(singleObservableOfData.asSingle())
                
            case .multipartUpload:
                if let uploadableData = input as? Uploadable {
                    let endPoint = Endpoint(path: self.path, fileName: uploadableData.fileName, type: uploadableData.type, key: uploadableData.key, method: self.method)
                    let singleObservableOfData = networkClient.upload(withEndPoint: endPoint, data: uploadableData.formData).map({ (response) -> Data in
                        if PO.self is HeaderFetchable.Type {
                            let data = self.setHeader(fromResponse: response)
                            return data
                        }
                        return response.data
                    })
                    return parser(singleObservableOfData.asSingle())

                } else {
                    fatalError("Input parameter must be uploadable.")
                }
            }
        }
    }
    
    private func setHeader(fromResponse response:Response) -> Data {
        do {
            var json = try JSONSerialization.jsonObject(with: response.data, options: []) as? [String : Any]
            if var body:[String: Any] = json!["body"] as? [String:Any] {
                body["headerParameters"] = response.headerFields
                json!["body"] = body
            }
            let data = try JSONSerialization.data(withJSONObject: json!, options: [])
            return data
        } catch {
            print("Error occurred during JSON serialization.")
        }
        
        return response.data
    }
    
    private func composeDynamicPath(withInput input:I, withPath path:String) -> String {
        var path = path
        for case let(label?,value) in Mirror(reflecting: input).children {
            guard let str =  value as? String else {
                fatalError("Value must be convertible to string")
            }
            path = path.replacingOccurrences(of: "{\(label)}", with: str)
        }
        return path
    }
    
}

/**
    Implementation of database datasource.
 */

public enum DataBaseOperation {
    case insertObj
    case deleteObj
    case updateObj
    case getObj
}

public struct DatabaseDataSource<I> : DataSourceGeneratable {
    
    private var operation: DataBaseOperation!
    private var manager:DataBaseManager<NSObject>
    init(withDataBaseOperation operation: DataBaseOperation , databaseManager: DataBaseManager<NSObject>) {
        self.operation = operation
        manager = databaseManager
    }
    
    public func generate() -> DataSourceClosure<I, NSObject> {
        return self.generate { outputToParse in
            return outputToParse
        }
    }
    
    public func generate<PO>(parser: @escaping ParserClosure<NSObject, PO>) -> DataSourceClosure<I,PO> {
        return {(_ input: I) in
            let dbManager = DatabaseManagerFactory.getFactory().getDatabaseManager(withManager: self.manager)
            var singleObservableOfData: Single<NSObject>!
            switch self.operation! {
            case .insertObj:
                singleObservableOfData = dbManager.insert(object: input as! NSObject)
            case .deleteObj:
                singleObservableOfData = dbManager.delete(object: input as! NSObject)
            case .getObj:
                singleObservableOfData = dbManager.getObject(ofType: input as! NSObject.Type)
            case .updateObj:
                singleObservableOfData = dbManager.update(object: input as! NSObject)
            }
            let parserOutput = parser(singleObservableOfData)
            return parserOutput
        }
    }

}
