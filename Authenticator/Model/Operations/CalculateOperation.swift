//
//  CalculateOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/4/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class CalculateOperation: OATHOperation {
    private let credential: Credential
    private var timer: Timer?

    override var operationName: OperationName {
        return OperationName.calculate
    }
    
    override var uniqueId: String {
        return "\(operationName) " + credential.uniqueId
    }


    init(credential: Credential) {
        self.credential = credential
        super.init()
    }
    
    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
       
        self.credential.state = .calculating
        if self.credential.requiresTouch {
            operationRequiresTouch()
        } else if self.credential.type == .HOTP {
            // set timer and invoke
            // delegate?.onTouchRequired() if operation is not completed within 1 second
            // to workaround HOTP credentials that don't have requiresTouch flag
            let timer = Timer(timeInterval: 1.0, repeats: false, block: { [weak self] (timer) in
                guard let self = self else {
                    return
                }

                self.operationRequiresTouch()
            })
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
        
        // Adding 10 extra seconds to current timestamp as boost and improvement for quick code expiration:
        // If < 10 seconds remain on the validity of a code at time of generation,
        // increment the timeslot for the challenge and increase the validity time by the period of the credential.
        // For example, if 7 seconds remain at time of generation, on a 30 second credential,
        // generate a code for the next timeslot and show a timer for 37 seconds.
        // Even if the user is very quick to enter and submit the code to the server,
        // it is very likely that it will be accepted as servers typically allow for some clock drift.
        let request = YKFKeyOATHCalculateRequest(credential: self.credential.ykCredential,
                                                 timestamp: Date().addingTimeInterval(10))
        oathService.execute(request!) { [weak self] (response, error) in
            guard let self = self else {
                return
            }

            self.timer?.invalidate()

            guard error == nil else {
                self.operationFailed(error: error!)
                return
            }
            guard let response = response else {
                self.operationFailed(error: KeySessionError.noResponse)
                return
            }
            self.credential.setCode(code: response.otp, validity: response.validity)
            self.credential.state = .active
            self.operationSucceeded()
        }
    }

    override func operationFailed(error: Error) {
        // failure to calculate credential leads from calculating to expiration state
        self.credential.state = .expired
        super.operationFailed(error: error)
    }
    
    override func createRetryOperation() -> OATHOperation {
        return CalculateOperation(credential: self.credential)
    }
    
    override func invokeDelegateCompletion() {
        delegate?.onUpdate(credential: self.credential)
    }
}
