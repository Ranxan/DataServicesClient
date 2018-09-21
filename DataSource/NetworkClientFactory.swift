//
//  NetworkClientFactory.swift
//  NetworkCaller
//
//  Created by Ranxan Adhikari on 8/10/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation

public protocol NetworkClientFactoryProtocol {
    func getNetworkClient(withSessionType type: SessionType, baseUrl url:String) -> NetworkClient
}

public class NetworkClientFactory: NetworkClientFactoryProtocol {
    
    public init() {}
    
    deinit {
        print("Deinit NetworkClientFactory")
    }
    
    static var networkClientFactory: NetworkClientFactory?
    
    public class func setFactory(clientFactory: NetworkClientFactory) {
        NetworkClientFactory.networkClientFactory = clientFactory
    }
    
    public class func getFactory() -> NetworkClientFactory {
        if(NetworkClientFactory.networkClientFactory==nil){
            NetworkClientFactory.networkClientFactory = NetworkClientFactory()
        }
        return NetworkClientFactory.networkClientFactory!
    }
    
    public func getNetworkClient(withSessionType type: SessionType, baseUrl url:String) -> NetworkClient {
        let baseUrl = URL(string: url)
        return NetworkClient(withSessionType: type, baseUrl: baseUrl!)
    }
    
}
