//
//  NetworkCaller.swift
//  NetworkCaller
//
//  Created by Gurung Bishow on 6/7/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import RxSwift
import Alamofire
import RxCocoa

extension Data {
    private static let mimeTypeSignatures: [UInt8 : String] = [
        0xFF : "image/jpeg",
        0x89 : "image/png",
        0x47 : "image/gif",
        0x49 : "image/tiff",
        0x4D : "image/tiff",
        0x25 : "application/pdf",
        0xD0 : "application/vnd",
        0x46 : "text/plain",
        ]
    
    var mimeType: String {
        var c: UInt8 = 0
        copyBytes(to: &c, count: 1)
        return Data.mimeTypeSignatures[c] ?? "application/octet-stream"
    }
}

extension Encodable {
    var dictionary: [String: Any]? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)).flatMap { $0 as? [String: Any] }
    }
}

public typealias Parameters = [String: Any]
public typealias Path = String
public typealias Method = HTTPMethod

protocol ClientProtocol {
    func request(withEndpoint endpoint: Endpoint) -> Observable<Response>
}

public protocol Uploadable {
    var formData: Data {get}
    var fileName: String {get}
    var type: String? {get}
    var key: String {get}
}

struct Response {
    var data:Data
    var headerFields:[AnyHashable:Any]?
}

//MARK: Endpoint
final class Endpoint {
    let method: Method
    var path: Path
    var parameters: Parameters?
    
    var fileName: String?
    var type: String?
    var key: String?
    
    init(method: Method = .get, path: Path, parameters: Parameters? = nil) {
        self.method = method
        self.path = path
        self.parameters = parameters
    }
    
    init(method: Method = .get, path: Path, parameters: Void) {
        self.method = method
        self.path = path
    }
    
    init(method: Method = .get, path: Path, parameters: Encodable) {
        self.method = method
        self.path = path
        self.parameters = parameters.dictionary
    }
    
    init(path: Path, fileName: String, type: String? = nil, key: String, method: Method) {
        self.path = path
        self.fileName = fileName
        self.type = type
        self.key = key
        self.method = method
    }
    
    func appendPath(withString subPath:String) {
        path.append(subPath)
    }
}

public enum SessionType {
    case defaultConfig
    case ephemeral
    case background(identifier: String)
}

/** Creates and provides required session manager configurations to initiate the requests.
 Default session manager is created for general network requests. Once created, this configuration is reused.
 Ephimeral session manager is created for private network requests with limited scope and life cycle. Once created, this session manager is reused.
 Background session manager is created with unique identifier to upload, download or request large volume of data over the network. Each background session is unique in the application.
 If background session of id 'X' is still working and tried to create a new background session with the same id 'X', warning is thrown. Identifier needs to be a valid non-empty string.
 */
class NetworkSessionManager {
    private static var networkSessionManager: NetworkSessionManager!
    private var defaultSessionManager: SessionManager!
    private var ephimeralSessionManager: SessionManager!
    
    private init() {}
    
    func createSession(type: SessionType) -> SessionManager {
        switch type {
        case .defaultConfig:
                if defaultSessionManager == nil {
                    defaultSessionManager = Alamofire.SessionManager(configuration: URLSessionConfiguration.default)
                }
                return defaultSessionManager
        case .ephemeral:
            if ephimeralSessionManager == nil {
                ephimeralSessionManager = Alamofire.SessionManager(configuration: URLSessionConfiguration.ephemeral)
            }
            return ephimeralSessionManager
        case .background(let identifier):
            let backgroundSessionManager = Alamofire.SessionManager(configuration: URLSessionConfiguration.background(withIdentifier: identifier))
            return backgroundSessionManager
        }
    }
    
    public static func getNetworkSessionManager() -> NetworkSessionManager {
        if networkSessionManager == nil {
            networkSessionManager = NetworkSessionManager()
        }
        return networkSessionManager
    }
}

struct ClientType : RawRepresentable, Equatable, Hashable, Comparable {
    typealias RawValue = String
    var rawValue: String
    static let defaultConfig  = ClientType(rawValue: "defaultConfig")
    static let ephemeral = ClientType(rawValue: "ephemeral")
    static let background = ClientType(rawValue: "background")
    
    //MARK: Hashable
    var hashValue: Int {
        return rawValue.hashValue
    }
    
    //MARK: Comparable
    public static func <(lhs: ClientType, rhs: ClientType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

public class NetworkClient: ClientProtocol {
    
    public let manager: Alamofire.SessionManager
    public static var adapter = Adapter()
    public static var retrier = Retrier()

    private var baseURL = URL(string: "http://")!

    init(withSessionType type: SessionType = .defaultConfig, baseUrl url:URL) {
        let networkSessionManager = NetworkSessionManager.getNetworkSessionManager()
        manager = networkSessionManager.createSession(type: type)
        manager.adapter = NetworkClient.adapter
        manager.retrier = NetworkClient.retrier
        baseURL = url
    }
    
    deinit {
        print("Deinit NetworkClient")
    }
    
     @discardableResult func request(withEndpoint endpoint: Endpoint) -> Observable<Response> {
        return Observable<Response>.create { observer -> Disposable in
            let request = self.manager.request(self.getUrl(path: endpoint.path),
                method: endpoint.method,
                parameters: endpoint.parameters, encoding: URLEncoding.default,
                headers: nil).validate(statusCode: 200...300)
                request.responseData() { response in
                    switch response.result {
                    case .success(let value):
                        observer.onNext(Response(data: value, headerFields: response.response?.allHeaderFields))
                        observer.onCompleted()
                    case .failure(let error):
                        observer.onError(NetworkErrorParser().returnParsedError(fromNetworkError: error, andData: response.data!))
                        observer.onCompleted()
                    }
                }
            return Disposables.create {
                request.cancel()
            }
        }
    }
    
    @discardableResult func upload(withEndPoint endpoint: Endpoint, data: Data, progressValue: @escaping (_ progress: Progress?) -> () = { _ in }) -> Observable<Response> {
        guard let uploadKey = endpoint.key else {
            fatalError("Could not find the key to upload the file.")
        }
        
        let multipartFormData = MultipartFormData()
        multipartFormData.append(data, withName: uploadKey, fileName: endpoint.fileName!, mimeType:data.mimeType)
       
        if let bodyPartType = endpoint.type {
            multipartFormData.append(bodyPartType.data(using: .utf8)!, withName: "type")
        } else {
            print("Type not set for this image")
        }
        
        guard let data = try? multipartFormData.encode() else {
            fatalError("Could not decode data")
        }
        
        return Observable<Response>.create{ (observer) -> Disposable in
            let request = self.manager.upload(data,
                                         to: self.getUrl(path: endpoint.path),
                                         method: .post,
                                         headers: ["Content-Type": multipartFormData.contentType]).validate(statusCode: 200...300)
            request.responseData(completionHandler: {(response) in
                switch response.result {
                case .success(let value):
                    observer.onNext(Response(data: value, headerFields: response.response?.allHeaderFields))
                    observer.onCompleted()
                case .failure(let error):
                    observer.onError(NetworkErrorParser().returnParsedError(fromNetworkError: error, andData: response.data!))
                    observer.onCompleted()
                }
            })
            
            request.uploadProgress(closure: { (progress) in
                progressValue(progress)
            })
            
            return Disposables.create {
                request.cancel()
            }
        }
    }
    
    private func appendPath(toBaseUrl path: Path) -> URL {
        return path.contains("http") ? baseURL : baseURL.appendingPathComponent(path)
    }

    private func getUrl(path:Path) -> URL{
        return appendPath(toBaseUrl: path)
    }
    
}
