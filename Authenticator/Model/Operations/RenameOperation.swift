//
//  RenameOperation.swift
//  Authenticator
//
//  Created by Jens Utbult on 2020-04-17.
//  Copyright © 2020 Yubico. All rights reserved.
//

import UIKit

class RenameOperation: OATHOperation {
    private let credential: Credential
    private let issuer: String
    private let account: String
    
    override var operationName: OperationName {
        return OperationName.rename
    }

    init(credential: Credential, issuer: String, account: String) {
        self.credential = credential
        self.issuer = issuer
        self.account = account
        super.init()
    }
    
    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.execute(YKFKeyOATHRenameRequest(credential: credential.ykCredential, issuer: issuer, account: account)!) {  [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            // The request was successful. The credential was added to the key.
            self?.operationSucceeded()
        }
    }
    
    override func createRetryOperation() -> OATHOperation {
        return RenameOperation(credential: self.credential, issuer: self.issuer, account: self.account)
    }
}
