//
//  CalculateAllOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/8/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class CalculateAllOperation: BaseOATHOperation {
    override var operationName: OperationName {
        return OperationName.calculateAll
    }

    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.executeCalculateAllRequest() { [weak self] (response, error) in
            guard let strongSelf = self else {
                return
            }
            
            guard error == nil else {
                strongSelf.operationFailed(error: error!)
                return
            }
            // If the error is nil the response cannot be empty.
            guard let response = response else {
                strongSelf.operationFailed(error: KeySessionError.noResponse)
                return
            }
            
            strongSelf.operationSucceeded(credentials: response.credentials.map {
                let result = Credential(fromYKFOATHCredentialCalculateResult: ($0 as! YKFOATHCredentialCalculateResult))
                return result
            })
        }        
    }
    
    override func retryOperation() -> BaseOATHOperation {
        return CalculateAllOperation()
    }
}
