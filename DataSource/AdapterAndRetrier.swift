//
//  NetworkAdapter.swift
//  NetworkCaller
//
//  Created by Gurung Bishow on 10/7/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift

public class Adapter: RequestAdapter {
    
    public func adapt(_ urlRequest: URLRequest) throws -> URLRequest {
        var urlRequestConfig = urlRequest
        if  let uuid = UIDevice.current.identifierForVendor?.uuidString{
            urlRequestConfig.setValue(uuid, forHTTPHeaderField:"Device-Id")
        }
        
        urlRequestConfig.setValue("en", forHTTPHeaderField: "Locale")
        urlRequestConfig.setValue("ios", forHTTPHeaderField: "Platform")
        
        if let authToken = AuthTokensManager.getAuthToken(), !authToken.isEmpty {
            let theToken = "Bearer \(authToken)"
            urlRequestConfig.setValue(theToken, forHTTPHeaderField: "Authorization")
        }
        
        return urlRequestConfig
    }
    
}

public class AuthTokensManager {
    
    public struct TokenModel: Encodable {
        init() {}
        public var refreshToken: String?
        public enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }
    
    public struct TokenResponseModel: Decodable, HeaderFetchable {
        public var headerParameters: [String : String]
        public enum CodingKeys: String, CodingKey {
            case headerParameters
        }
    }
    
    public struct AuthTokens {
        public static let refreshTokenDataSource = DatasourceWithBaseResponse<TokenModel, TokenResponseModel>(withPath: "auth/refresh-token",HTTPMethod: .post).generate()
    }
    
    public static let KEY_ACCESS_TOKEN = "ACCESS_TOKEN"
    public static let KEY_REFRESH_TOKEN = "REFRESH_TOKEN"
    public static let KEY_ACCESS_TOKEN_EXPIRES_IN = "EXPIRES_IN"
    public static let KEY_TIME_STAMP_FOR_TOKEN_REFRESH = "TIME_STAMP_TOKEN_REFRESH"
    public static let MSG_ERROR_REFRESH_TOKEN_NOT_FOUND = "Could not find the refresh token!"
    public static let MSG_ERROR_REFRESH_TOKEN_FAILED = "Refreshing the token failed!"
    public static var userDefaults = UserDefaults.standard

    public var authTokenManagerObservable: Single<Bool>?
    public var disposables: Disposables?
    
    public let disposeBag = DisposeBag()
    public var disposableOfRefreshTokenDataSource: Disposable?
    
    public init() {}
    
    deinit {
        disposableOfRefreshTokenDataSource?.disposed(by: disposeBag)
        print("Deinit AuthTokensManager")
    }

    public func refreshTokens() -> Single<Bool> {
        authTokenManagerObservable = Single.create { singleEvent in
            
            guard let refreshToken = AuthTokensManager.getRefreshToken() else {
                print(AuthTokensManager.MSG_ERROR_REFRESH_TOKEN_NOT_FOUND)
                singleEvent(.error(NetworkError.apiError(apiMessage: AuthTokensManager.MSG_ERROR_REFRESH_TOKEN_NOT_FOUND)))
                return Disposables.create {
                    print("Disposed.")
                }
            }
            
            var tokenModel = TokenModel()
            tokenModel.refreshToken = refreshToken
            self.disposableOfRefreshTokenDataSource = AuthTokens.refreshTokenDataSource(tokenModel).subscribe { event in
                switch(event) {
                case .success(let model):
                    let headerParameters = model.headerParameters
                    let authToken = headerParameters["Access-Token"]
                    let refreshToken = headerParameters["Refresh-Token"]
                    let secondsToExpire = Int(headerParameters["Expires-In"] ?? "0")
                    AuthTokensManager.setAuthTokens(authToken: authToken, refreshToken: refreshToken, expirySeconds: secondsToExpire)
                    singleEvent(.success(true))
                    break
                case .error(let error):
                    print(error)
                    singleEvent(.error(NetworkError.apiError(apiMessage: AuthTokensManager.MSG_ERROR_REFRESH_TOKEN_FAILED)))
                    break
                }
            }
            
            return Disposables.create {
                print("Disposed.")
            }
        }
        
        return authTokenManagerObservable!
    }
    
    class func compareAuthTokens(authTokenFromResponseHeader: String) -> Bool {
        let privateAuthToken = AuthTokensManager.getAuthToken()
        return privateAuthToken == authTokenFromResponseHeader
    }
    
    public class func setAuthTokens(authToken: String?, refreshToken: String?, expirySeconds: Int?) {
        userDefaults.set(authToken, forKey: AuthTokensManager.KEY_ACCESS_TOKEN)
        userDefaults.set(refreshToken, forKey: AuthTokensManager.KEY_REFRESH_TOKEN)
        userDefaults.set(expirySeconds, forKey: AuthTokensManager.KEY_ACCESS_TOKEN_EXPIRES_IN)
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
        let now = dateformatter.string(from: Date())
        userDefaults.set(now, forKey: AuthTokensManager.KEY_TIME_STAMP_FOR_TOKEN_REFRESH)
    }
    
    public class func getAuthToken() -> String? {
        let authToken = userDefaults.string(forKey: AuthTokensManager.KEY_ACCESS_TOKEN)
        return authToken
    }
    
    public class func getRefreshToken() -> String? {
        let refreshToken = userDefaults.string(forKey: AuthTokensManager.KEY_REFRESH_TOKEN)
        return refreshToken
    }
    
    public class func hasAuthTokenExpired() -> Bool {
        guard let dateForAvailableAuthTokenAsString = userDefaults.string(forKey: AuthTokensManager.KEY_TIME_STAMP_FOR_TOKEN_REFRESH) else {
            return true
        }
        
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "yyyy-MM-dd HH:mm:ss z"
        if let dateForAvailableAuthToken = dateformatter.date(from: dateForAvailableAuthTokenAsString) {
            let expirtyTimeIntervalInSeconds = userDefaults.integer(forKey: AuthTokensManager.KEY_ACCESS_TOKEN_EXPIRES_IN)
            let expiryDateForAvailableAuthTokenInSeconds = dateForAvailableAuthToken.timeIntervalSince1970 + Double(expirtyTimeIntervalInSeconds)
            let timeIntervalTillNowInSeconds = Date().timeIntervalSince1970
            if timeIntervalTillNowInSeconds < expiryDateForAvailableAuthTokenInSeconds {
                return false
            }
        }
        return true
    }
    
    public class func resetAuthToken() {
        userDefaults.removeObject(forKey: AuthTokensManager.KEY_ACCESS_TOKEN)
    }
    
}

public class Retrier: RequestRetrier {
    
    public struct RetryPolicy {
        public init() {}
        public static var expectedRetryCounts = 3
        public var timeIntervalAfterEachRequest: Double = 0.0
    }
    
    let lock = NSLock()
    
    var retryPolicy: RetryPolicy!
    var oAuthTokenManager: AuthTokensManager?
    var authenticationTokenFailureStatus = 401
    
    let disposeBag = DisposeBag()
    var disposableOfRefreshTokenHandler: Disposable?
    
    static var requestsToRetry: [RequestRetryCompletion] = []
    static var isRefreshingToken = false
    
    public init(authTokenManager: AuthTokensManager = AuthTokensManager(), retryPolicy: RetryPolicy = RetryPolicy()) {
        self.oAuthTokenManager = authTokenManager
        self.retryPolicy = retryPolicy
    }
    
    deinit {
        disposableOfRefreshTokenHandler?.disposed(by: disposeBag)
        oAuthTokenManager = nil
        retryPolicy = nil
        print("Deinit Retrier")
    }

    public func should(_ manager: SessionManager, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        lock.lock(); defer {lock.unlock()}
        
        guard let response = request.task?.response as? HTTPURLResponse else {
            print("Could not receive an instance of a response.")
            completion(false, 0.0)
            return
        }
        
        guard request.retryCount <= RetryPolicy.expectedRetryCounts else {
            completion(false, 0.0)
            return
        }
        
        guard response.statusCode == authenticationTokenFailureStatus else {
            completion(false, 0.0)
            return
        }
    
        Retrier.requestsToRetry.append(completion)
        if Retrier.isRefreshingToken == false {
            Retrier.isRefreshingToken = true
            if AuthTokensManager.hasAuthTokenExpired() {
                refreshAuthenticationTokens()
            } else {
                Retrier.requestsToRetry.forEach({$0(true, 0.0)})
                Retrier.isRefreshingToken = false
            }
        }
    }
    
    func refreshAuthenticationTokens() {
        if oAuthTokenManager == nil {
            oAuthTokenManager = AuthTokensManager()
        }
        
        disposableOfRefreshTokenHandler = oAuthTokenManager!.refreshTokens().subscribe { [weak self] singleEvent in
            Retrier.isRefreshingToken = false
            
            switch singleEvent {
            case .success(let tokensRefreshed):
                if tokensRefreshed == true {
                    self?.retryPolicy.timeIntervalAfterEachRequest += 1.0
                    Retrier.requestsToRetry.forEach({$0(true, self?.retryPolicy.timeIntervalAfterEachRequest ?? 0.0)})
                } else {
                    AuthTokensManager.resetAuthToken()
                    Retrier.requestsToRetry.forEach({$0(false, 0.0)})
                }
                break
                
            case .error(let error):
                print(error.localizedDescription)
                Retrier.requestsToRetry.forEach({$0(false, 0.0)})
                break
            }
            
            Retrier.requestsToRetry.removeAll()
        }
    }
    
}

