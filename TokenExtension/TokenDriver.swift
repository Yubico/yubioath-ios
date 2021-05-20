//
//  TokenDriver.swift
//  TokenExtension
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import CryptoTokenKit

class TokenDriver: TKTokenDriver, TKTokenDriverDelegate {

    func tokenDriver(_ driver: TKTokenDriver, tokenFor configuration: TKToken.Configuration) throws -> TKToken {
        return Token(tokenDriver: self, instanceID: configuration.instanceID)
    }

}
