//
//  SettingsConfig.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/14/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

/*! Allows to customize behavior of the app
 Using UserDefaults as permanent storage
 */
class SettingsConfig {
    static private let NO_SERVICE_WARNING = "nfcwarning"
    static private let ALLOW_BACKUP = "backup"
    static private let FRE_SHOWN = "freShown"

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
    
    static var isFreShown : Bool {
        get {
            return UserDefaults.standard.bool(forKey: FRE_SHOWN)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: FRE_SHOWN)
        }
    }
}
