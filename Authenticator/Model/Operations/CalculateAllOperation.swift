//
//  CalculateAllOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/8/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class CalculateAllOperation: OATHOperation {
    var credentials: Array<Credential>?
    
    override var operationName: OperationName {
        return OperationName.calculateAll
    }
    
    override init() {
        super.init()
        self.queuePriority = .low
    }

    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        let request = YKFKeyOATHCalculateAllRequest(timestamp: Date().addingTimeInterval(10))
        oathService.execute(request!) { [weak self] (response, error) in
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
            
            self.credentials = response.credentials.map {
                return Credential(fromYKFOATHCredentialCalculateResult: ($0 as! YKFOATHCredentialCalculateResult), keyVersion: response.keyVersion)
            }

            self.operationSucceeded()
        }        
    }
    
    override func createRetryOperation() -> OATHOperation {
        return CalculateAllOperation()
    }
    
    override func invokeDelegateCompletion() {
        delegate?.onUpdate(credentials: self.credentials!)
    }
}
