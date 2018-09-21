//
//  BaseUrl.swift
//  NetworkCaller
//
//  Created by Nutan Niraula on 8/14/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation

public struct BaseUrl {
    public static var AppBaseUrl = "https://domain.com/services/route"
}

public class ResponseStatus: Decodable {
    public var code: String?
    public var message: String?
    public var codeText: String?
    public var responseTimeStamp: String?
    
    required public init() {}
    
    private enum CodingKeys: String, CodingKey {
        case code
        case codeText = "code_text"
        case message
        case responseTimeStamp = "response_timestamp"
    }
}

public class BaseResponse<T:Decodable>:Decodable {
    public var status: ResponseStatus?
    public var body: T?
    
    private enum CodingKeys: String, CodingKey {
        case status
        case body
    }
    
    required public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(ResponseStatus.self, forKey: .status)
        body  = try container.decodeIfPresent(T.self, forKey: .body)
    }
}
