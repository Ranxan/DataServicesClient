//
//  DataParser.swift
//  NetworkCaller
//
//  Created by Nutan Niraula on 7/19/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import RxSwift
import Alamofire

extension ObservableType where E == Data {
    func parsefromJson<Response: Decodable>(toModelType modelType: Response.Type) -> Observable<Response> {
        return self.asObservable().map { (response) -> Response in
            let parserResponse = self.parseJson(toModelType: modelType, fromData: response)
            if let parsedResponse = parserResponse.parsedModel {
                return parsedResponse
            } else {
                throw parserResponse.error!
            }
        }
    }
    
    func parseJsonToBaseResponse<Response: Decodable>(withResponseType modelType: Response.Type) -> Observable<Response> {
        return self.asObservable().map { (response) -> Response in
            let parserResponse = self.parseJson(toModelType: BaseResponse<Response>.self, fromData: response)
            if let parsedResponse = parserResponse.parsedModel {
                if let body = parsedResponse.body {
                    return body
                } else {
                    throw NetworkError.apiError(apiMessage: (parsedResponse.status?.message!)!)
                }
            } else {
                throw parserResponse.error!
            }
        }
    }
    
    private func parseJson<T: Decodable>(toModelType: T.Type, fromData data: Data) -> (parsedModel:T?, error: Error?) {
        do {
            let responseModel = try JSONDecoder().decode(T.self,from: data)
            return (responseModel, nil)
        } catch let err {
            return (nil, err)
        }
    }
}

extension ObservableType where E == NSObject {
    
    func parsefromObject() -> Observable<NSObject> {
        return self.asObservable()
    }
    
}
