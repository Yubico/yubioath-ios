//
//  Ramps.swift
//  Authenticator
//
//  Created by Irina Makhalova on 11/7/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

/*! Allows to customize behavior of the app
 Using UserDefaults as permanent storage
 */
class Ramps {
    static private let NO_SERVICE_WARNING = "nfcwarning"
    static private let ALLOW_BACKUP = "backup"

    static var showNoServiceWarning : Bool {
        get {
            return UserDefaults.standard.bool(forKey: NO_SERVICE_WARNING)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: NO_SERVICE_WARNING)
        }
    }
    
    static var showBackupWarning : Bool {
        get {
            return UserDefaults.standard.bool(forKey: ALLOW_BACKUP)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ALLOW_BACKUP)
        }
    }
}
