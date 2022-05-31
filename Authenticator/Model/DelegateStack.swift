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

class DelegateStack {
    
    static let shared = DelegateStack()
    private var weakDelegates = [Weak<YKFManagerDelegate>]()
    
    func setDelegate(_ delegate: YKFManagerDelegate) {
        YubiKitManager.shared.delegate = delegate
        weakDelegates.append(Weak(value: delegate))
    }
    
    func removeDelegate(_ delegate: YKFManagerDelegate) {
        // if last is weak it's likely deinited, remove it and set next as delegate
        if weakDelegates.count > 0 && weakDelegates.last?.value == nil {
            weakDelegates.removeLast()
            YubiKitManager.shared.delegate = weakDelegates.last?.value
            return
            
        // if last is delegate remove it and set next as delegate
        } else if let last = weakDelegates.last?.value, last.isEqual(delegate) {
            weakDelegates.removeLast()
            YubiKitManager.shared.delegate = weakDelegates.last?.value
            return
            
        // in all other cases we can simply remove the delegate
        } else {
            let index = weakDelegates.firstIndex { weak in
                guard let stackedDelegate = weak.value else { return false }
                return stackedDelegate.isEqual(delegate)
            }
            if let index = index {
                weakDelegates.remove(at: index)
            }
            // Remove any lingering nilled delegates that are in the middle of the stack
            weakDelegates = weakDelegates.filter { nil != $0.value }
        }
    }
    
    private init() { }
}

private class Weak<T: AnyObject> {
    weak var value : T?
    init (value: T) {
        self.value = value
    }
}
