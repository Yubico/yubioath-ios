//
//  ReadOTPOperation.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 3/30/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

import Foundation

class ReadOTPOperation: OTPOperation {
    var token: YKFOTPTokenProtocol?
    
    override var operationName: OperationName {
        return OperationName.readOtpToken
    }

    override func executeOperation(otpService: YKFNFCOTPServiceProtocol) {
        otpService.requestOTPToken { [weak self] (token, error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            guard let token = token else {
                self?.operationFailed(error: KeySessionError.noResponse)
                return
            }
            
            self?.token = token
            self?.operationSucceeded()
        }
    }
    
    override func createRetryOperation() -> OTPOperation {
        return ReadOTPOperation()
    }
    
    override func invokeDelegateCompletion() {
        delegate?.onReadOtpToken(token: self.token!)
    }
}
