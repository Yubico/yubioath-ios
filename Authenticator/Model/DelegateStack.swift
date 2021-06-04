//
//  DelegateStack.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-06-04.
//  Copyright © 2021 Yubico. All rights reserved.
//

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
