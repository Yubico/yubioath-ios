//
//  OTPOperation.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 3/30/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

import Foundation

class OTPOperation: BaseOperation {

    override func executeOperation() {
        let keyPluggedIn = YubiKitManager.shared.accessorySession.sessionState == .open

        let otpService: YKFNFCOTPServiceProtocol
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags && !keyPluggedIn {
            guard #available(iOS 13.0, *) else {
                fatalError()
            }
            
            otpService = YubiKitManager.shared.nfcSession.otpService
            self.executeOperation(otpService: otpService)
        }
    }
    
    func executeOperation(otpService: YKFNFCOTPServiceProtocol) {
        fatalError("Override in the OTP specific operation subclass.")
    }
}
