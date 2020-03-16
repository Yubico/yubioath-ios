//
//  PutOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit
import FirebaseAnalytics

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
    
    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.execute(YKFKeyOATHPutRequest(credential: credential)!) {  [weak self] (error) in
            guard let self = self else {
                return
            }
            guard error == nil else {
                self.operationFailed(error: error!)
                return
            }
            
            // The request was successful. The credential was added to the key.
            self.operationSucceeded()
            
            let type = self.credential.type.rawValue
            let requiresTouch = self.credential.requiresTouch
            Analytics.logEvent("add_credential_complete", parameters: ["require_touch" : (requiresTouch ? "yes" : "no"),
                                                                       "type" : type == 32 ? "totp" : "hotp",
                                                                       "algorithm" : self.credential.algorithm.rawValue,
                                                                       "digits" : self.credential.digits,
                                                                       "period" : self.credential.period])
        }
    }
    
    override func createRetryOperation() -> OATHOperation {
        return PutOperation(credential: self.credential)
    }

}

fileprivate extension YKFOATHCredential {
    var uniqueId: String {
        get {
            if type == YKFOATHCredentialType.TOTP {
                return String(format:"%d/%@:%@", self.period, self.issuer ?? "", self.account);
            } else {
                return String(format:"%@:%@", self.issuer ?? "", self.account);
            }
        }
    }
}
