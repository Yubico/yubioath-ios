//
//  OATHOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/4/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class OATHOperation: BaseOperation {

    override func main() {
        if isCancelled {
            return
        }

        let keyPluggedIn = YubiKitManager.shared.accessorySession.sessionState == .open

        let oathService: YKFKeyOATHServiceProtocol
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags && !keyPluggedIn {
            guard #available(iOS 13.0, *) else {
                fatalError()
            }
            guard let service = YubiKitManager.shared.nfcSession.oathService else {
                self.operationFailed(error: KeySessionError.noService)
                return
            }
            oathService = service
        } else {
            guard let service = YubiKitManager.shared.accessorySession.oathService else {
                self.operationFailed(error: KeySessionError.noService)
                return
            }
            oathService = service
        }

        executeOperation(oathService: oathService)

        waitOperationFinish()
    }
    
    func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        fatalError("Override in the OATH specific operation subclass.")
    }
}
