//
//  ObservableTransform.swift
//  NetworkCaller
//
//  Created by Nutan Niraula on 7/24/18.
//  Copyright © 2018 Gurung Bishow. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift

extension ObservableType where E == DataResponse<Data> {
    func toData() -> Observable<Data> {
        let mappedResponse = self.asObservable().map { (dataResponse) -> Data in
            if let data = dataResponse.data {
                return data
            } else {
                throw NetworkError.apiError(apiMessage: "Data Response from network is nil")
            }
        }
        return mappedResponse
    }
}
