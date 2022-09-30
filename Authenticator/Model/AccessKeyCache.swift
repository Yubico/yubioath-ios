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

struct AccessKeyCache {
    
    let timeToLive = TimeInterval(5*60)
    
    struct AccessKey {
        let timeStamp = Date()
        let accessKey: Data
        
        init(_ accessKey: Data) {
            self.accessKey = accessKey
        }
    }
    
    private var cache = [String: AccessKey]()
    
    mutating func accessKey(forKey index: String) -> Data? {
        guard let possibleAccessKey = cache[index] else { return nil }
        if Date() < Date(timeInterval: timeToLive, since: possibleAccessKey.timeStamp) {
            cache[index] = AccessKey(possibleAccessKey.accessKey)
            return possibleAccessKey.accessKey
        } else {
            cache.removeValue(forKey: index)
            return nil
        }
    }
    
    mutating func setAccessKey(_ accessKey: Data, forKey index: String) {
        let accessKey = AccessKey(accessKey)
        cache[index] = accessKey
    }
}
