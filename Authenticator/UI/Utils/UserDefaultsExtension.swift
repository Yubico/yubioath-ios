//
//  UserDefaultsExtension.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/12/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UserDefaults {
    
    private static let freFinishedKey = "freFinished"
    
    var freFinished: Bool {
        get {
            return bool(forKey: UserDefaults.freFinishedKey)
        }
        set {
            set(newValue, forKey: UserDefaults.freFinishedKey)
        }
    }
}
