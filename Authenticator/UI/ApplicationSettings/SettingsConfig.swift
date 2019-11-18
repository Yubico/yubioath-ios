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
    static private let noServiceWarning = "nfcwarning"
    static private let allowBackup = "backup"
    static private let freShown = "freShown"

    static var showNoServiceWarning: Bool {
        get {
            return UserDefaults.standard.bool(forKey: noServiceWarning)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: noServiceWarning)
        }
    }
    
    static var showBackupWarning: Bool {
        get {
            return UserDefaults.standard.bool(forKey: allowBackup)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: allowBackup)
        }
    }
    
    static var isFreShown : Bool {
        get {
            return UserDefaults.standard.bool(forKey: freShown)

        }
        set {
            UserDefaults.standard.set(newValue, forKey: freShown)
        }
    }
}
