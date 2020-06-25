//
//  YKFKeyVersion+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2020-05-14.
//  Copyright © 2020 Yubico. All rights reserved.
//

extension YKFKeyVersion: Comparable {
    
    static public func ==(lhs: YKFKeyVersion, rhs: YKFKeyVersion) -> Bool {
        return lhs.major == lhs.major && lhs.minor == rhs.minor && lhs.micro == rhs.micro
    }
    
    static public func <(lhs: YKFKeyVersion, rhs: YKFKeyVersion) -> Bool {
        if (lhs.major != rhs.major) {
            return lhs.major < rhs.major
        } else if (lhs.minor != rhs.minor) {
            return lhs.minor < rhs.minor
        } else {
            return lhs.micro < rhs.micro
        }
    }
    
}
