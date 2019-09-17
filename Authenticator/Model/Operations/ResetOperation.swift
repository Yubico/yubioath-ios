//
//  ResetOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class ResetOperation: BaseOATHOperation {
    override var operationName: OperationName {
        return OperationName.reset
    }

    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.executeResetRequest { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            self?.operationSucceeded()
        }
    }
    
    override func retryOperation() -> BaseOATHOperation {
        return ResetOperation()
    }
}
