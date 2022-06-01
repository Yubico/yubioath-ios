/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

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
