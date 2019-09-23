//
//  SetCodeOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class SetCodeOperation: OATHOperation {
    
    private let password: String
    
    override var operationName: OperationName {
        return OperationName.setCode
    }
    
    override var replicable: Bool {
        return true
    }

    init(password: String) {
        self.password = password
        super.init()
    }
    
    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.execute(YKFKeyOATHSetCodeRequest(password: password)!) { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            self?.operationSucceeded()
        }
    }
    
    override func createRetryOperation() -> OATHOperation {
        return SetCodeOperation(password: self.password)
    }
}
