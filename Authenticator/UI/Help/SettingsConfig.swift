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
    static private let freVersion = "freVersion"
    static private let whatsNewVersion = "whatsNewVersion"
    static private let userFoundMenu = "userFoundMenu"
    
    static var userHasFoundMenu: Bool {
        get {
            return UserDefaults.standard.bool(forKey: userFoundMenu)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userFoundMenu)
        }
    }

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
    
    static var lastFreVersionShown : Int {
        get {
            return UserDefaults.standard.integer(forKey: freVersion)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: freVersion)
        }
    }
    
    static var lastWhatsNewVersionShown : Int {
        get {
            return UserDefaults.standard.integer(forKey: whatsNewVersion)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: whatsNewVersion)
        }
    }
}
