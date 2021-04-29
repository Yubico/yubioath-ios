//
//  ValidateOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class ValidateOperation: OATHOperation {
    
    private let password: String
    
    override var operationName: OperationName {
        return OperationName.validate
    }
    
    override var replicable: Bool {
        return true
    }

    init(password: String) {
        self.password = password
        super.init()

        self.queuePriority = .high
    }
    /*
    override func executeOperation(oathService: YKFOATHSession) {
        if password.isEmpty {
            // SDK doesn't handle empty values
            self.operationFailed(error: NSError(domain: "", code: Int(YKFOATHErrorCode.wrongPassword.rawValue), userInfo: nil))
            return
        }
        oathService.execute(YKFOATHValidateRequest(password: password)!) { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            self?.operationSucceeded()
        }
    }*/
    
    override func createRetryOperation() -> OATHOperation {
        return ValidateOperation(password: self.password)
    }
}
