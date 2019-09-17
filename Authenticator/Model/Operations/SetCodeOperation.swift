//
//  SetCodeOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class SetCodeOperation: BaseOATHOperation {
    
    private let password: String
    
    override var operationName: OperationName {
        return OperationName.setCode
    }
    
    override var replacable: Bool {
        return true
    }

    init(password: String) {
        self.password = password
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
    
    override func retryOperation() -> BaseOATHOperation {
        return SetCodeOperation(password: self.password)
    }
}
