//
//  Parser.swift
//  NetworkCaller
//
//  Created by Gurung Bishow on 10/7/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import Alamofire

enum NetworkError: Error {
    case notConnectedToInternet
    case timeOut
    case cancelled
    case badUrl
    case networkConnectionLost
    case networkResourceUnavailable
    case apiError(apiMessage: String)
    case cannotParseJsonError
    case noMobileDataAvailable //return 410 status code
    case sixtyAttemptsExceededInOneMinute
}

extension NetworkError: LocalizedError  {
    public var errorDescription: String? {
        switch self {
        case .notConnectedToInternet :
            return NSLocalizedString("noConnection_error", comment: "No Internet")
        case .timeOut :
            return NSLocalizedString("timeOut_error", comment: "Request timed out")
        case .cancelled :
            return NSLocalizedString("requestCancelled_error", comment: "Request cancelled")
        case .badUrl :
            return NSLocalizedString("badUrl_error", comment: "Invalid url")
        case .networkConnectionLost :
            return NSLocalizedString("connectionLost_error", comment: "Connection lost")
        case .networkResourceUnavailable :
            return NSLocalizedString("networkResource_error", comment: "Resource unavailable")
        case .apiError (let msg) :
            return NSLocalizedString(msg, comment: "Error unknown")
        case .cannotParseJsonError :
            return NSLocalizedString("Cannot parse JSON", comment: "No Internet")
        case .noMobileDataAvailable :
            return NSLocalizedString("noConnection_error", comment: "No Internet")
        case .sixtyAttemptsExceededInOneMinute :
            return NSLocalizedString("You have exceeded your limit of 60 requests in one minute", comment: "No Internet")
        }
    }
}

final class NetworkErrorParser {
    func returnParsedError(fromNetworkError error:Error, andData data: Data) -> Error {
        let jsonString = String(data: data, encoding: String.Encoding.utf8) ?? "Data could not be printed"
        print(jsonString)
        print(error.localizedDescription)
        var toThrowError:NetworkError!
        switch error._code {
        case NSURLErrorNotConnectedToInternet:
            toThrowError =  NetworkError.notConnectedToInternet
        case NSURLErrorTimedOut:
            toThrowError = NetworkError.timeOut
        case NSURLErrorCancelled:
            toThrowError = NetworkError.cancelled
        case NSURLErrorBadURL:
            toThrowError = NetworkError.badUrl
        case NSURLErrorNetworkConnectionLost:
            toThrowError = NetworkError.networkConnectionLost
        case NSURLErrorResourceUnavailable:
            toThrowError = NetworkError.networkResourceUnavailable
        default :
            do {
                let tempJson =  try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                let status = tempJson?["status"] as? [String:Any]
                let msg = status?["message"] as? String
                toThrowError = NetworkError.apiError(apiMessage: msg ?? "Some thing went wrong")
            } catch {
                print(error.localizedDescription)
                toThrowError = NetworkError.apiError(apiMessage: "Some thing went wrong while parsing")
            }
        }
        return toThrowError
    }
}
