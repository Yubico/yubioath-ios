//
//  PutOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class PutOperation: OATHOperation {
    private let credential: YKFOATHCredential
    
    override var operationName: OperationName {
        return OperationName.put
    }
    
    override var uniqueId: String {
        return "\(operationName) " + credential.uniqueId
    }

    init(credential: YKFOATHCredential) {
        self.credential = credential
        super.init()
    }
    /*
    override func executeOperation(oathService: YKFOATHServiceProtocol) {
        oathService.execute(YKFOATHPutRequest(credential: credential)!) {  [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            // The request was successful. The credential was added to the key.
            self?.operationSucceeded()
        }
    }*/
    
    override func createRetryOperation() -> OATHOperation {
        return PutOperation(credential: self.credential)
    }

}

fileprivate extension YKFOATHCredential {
    var uniqueId: String {
        get {
            if type == YKFOATHCredentialType.TOTP {
                return String(format:"%d/%@:%@", self.period, self.issuer ?? "", self.accountName);
            } else {
                return String(format:"%@:%@", self.issuer ?? "", self.accountName);
            }
        }
    }
}
