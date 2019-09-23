//
//  CalculateAllOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/8/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class CalculateAllOperation: OATHOperation {
    override var operationName: OperationName {
        return OperationName.calculateAll
    }
    
    override init() {
        super.init()
        self.queuePriority = .low
    }

    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.executeCalculateAllRequest() { [weak self] (response, error) in
            guard let self = self else {
                return
            }
            
            guard error == nil else {
                self.operationFailed(error: error!)
                return
            }
            // If the error is nil the response cannot be empty.
            guard let response = response else {
                self.operationFailed(error: KeySessionError.noResponse)
                return
            }
            
            let credentials = response.credentials.map {
              return Credential(fromYKFOATHCredentialCalculateResult: ($0 as! YKFOATHCredentialCalculateResult))
            }

            self.operationSucceeded(credentials: credentials)
        }        
    }
    
    override func createRetryOperation() -> OATHOperation {
        return CalculateAllOperation()
    }
}
