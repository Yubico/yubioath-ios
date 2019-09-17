//
//  CalculateOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/4/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class CalculateOperation: BaseOATHOperation {
    private let credential: Credential
    private var timer: Timer?

    override var operationName: OperationName {
        return OperationName.calculate
    }
    
    override var uniqueId: String {
        return "\(operationName)" + credential.uniqueId
    }


    init(credential: Credential) {
        self.credential = credential
    }
    
    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        // TODO: check if calculation for this credential is in progress
        
        if (self.credential.requiresTouch) {
            operationRequiresTouch()
        } else if (self.credential.type == .HOTP){
            // set timer and invoke
            // delegate?.onTouchRequired() if operation is not completed within 1 second
            // to workaround HOTP credentials that don't have requiresTouch flag
            let timer = Timer(timeInterval: 1.0, repeats: false, block: { [weak self] (timer) in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.operationRequiresTouch()
            })
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        
        oathService.execute(YKFKeyOATHCalculateRequest(credential: self.credential.ykCredential)!) { [weak self] (response, error) in
            guard let strongSelf = self else {
                return
            }

            strongSelf.timer?.invalidate()

            guard error == nil else {
                strongSelf.operationFailed(error: error!)
                return
            }
            guard let response = response else {
                strongSelf.operationFailed(error: KeySessionError.noResponse)
                return
            }
            strongSelf.credential.code = response.otp
            strongSelf.credential.setValidity(validity: response.validity)
            strongSelf.operationSucceeded(credential: strongSelf.credential)
            print("Issuer \(strongSelf.credential.issuer) Account \(strongSelf.credential.account)")
        }
    }
    
    override func retryOperation() -> BaseOATHOperation {
        return CalculateOperation(credential: self.credential)
    }
}
