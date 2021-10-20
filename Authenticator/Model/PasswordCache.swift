//
//  PasswordCache.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-05.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

struct PasswordCache {
    
    let timeToLive = TimeInterval(5*60)
    
    struct Password {
        let timeStamp = Date()
        let password: String
        
        init(_ password: String) {
            self.password = password
        }
    }
    
    private var cache = [String: Password]()
    
    mutating func password(forKey index: String) -> String? {
        guard let possiblePassword = cache[index] else { return nil }
        if Date() < Date(timeInterval: timeToLive, since: possiblePassword.timeStamp) {
            cache[index] = Password(possiblePassword.password)
            return possiblePassword.password
        } else {
            cache.removeValue(forKey: index)
            return nil
        }
    }
    
    mutating func setPassword(_ password: String, forKey index: String) {
        let password = Password(password)
        cache[index] = password
    }
}
