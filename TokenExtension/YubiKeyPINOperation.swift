//
//  YubiKeyPINOperation.swift
//  TokenExtension
//
//  Created by Jens Utbult on 2021-12-15.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import CryptoTokenKit

class YubikeyPinOperation: TKTokenPasswordAuthOperation {

    override func finish() throws {
        guard let pin = self.password, pin.count >= 4 else { throw "Missing PIN" }
        
        if YubiKeyPIVSession.shared.verify(pin: pin) != nil { throw TKError(.authenticationFailed) }
        
        return
    }
}
