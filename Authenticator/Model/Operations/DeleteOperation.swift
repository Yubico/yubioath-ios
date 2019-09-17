//
//  DeleteOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class DeleteOperation: BaseOATHOperation {
    private let credential: Credential

    override var operationName: OperationName {
        return OperationName.delete
    }
    
    override var uniqueId: String {
        return "\(operationName):" + credential.uniqueId
    }
    
    init(credential: Credential) {
        self.credential = credential
    }
        
    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.execute(YKFKeyOATHDeleteRequest(credential: credential.ykCredential)!) { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            self?.operationSucceeded()
        }
    }
    
    override func retryOperation() -> BaseOATHOperation {
        return DeleteOperation(credential: self.credential)
    }

}
