//
//  Token.swift
//  TokenExtension
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import CryptoTokenKit

class Token: TKToken, TKTokenDelegate {

    func createSession(_ token: TKToken) throws -> TKTokenSession {
        return TokenSession(token:self)
    }

}
