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
    static private let bypassTouch = "bypassTouch"
    static private let nfcOnAppLaunch = "nfcOnAppLaunch"
    static private let showNFCSwipeHintCounter = "showNFCSwipeHintCounter"
    static private let showWhatsNewCounter = "showWhatsNewCounter"
    static private let showWhatsNewCounterAppVersion = "showWhatsNewCounterAppVersion"

    
    static var showWhatsNewText: Bool {
        get {
            if UIApplication.appVersion != UserDefaults.standard.string(forKey: showWhatsNewCounterAppVersion) {
                UserDefaults.standard.set(0, forKey: showWhatsNewCounter)
                UserDefaults.standard.set(UIApplication.appVersion, forKey: showWhatsNewCounterAppVersion)
            }
            let counter = UserDefaults.standard.integer(forKey: showWhatsNewCounter)
            // Show whats new text the first 3 times app is started
            if counter > 2 {
                return false
            } else {
                UserDefaults.standard.set(counter + 1, forKey: showWhatsNewCounter)
                return true
            }
        }
    }
    
    static func didShowWhatsNewText() {
        UserDefaults.standard.set(100, forKey: showWhatsNewCounter)
    }
    
    static var showNFCSwipeHint: Bool {
        get {
            let counter = UserDefaults.standard.integer(forKey: showNFCSwipeHintCounter)
            // Show swipe down hint the first 4 times
            if counter > 3 {
                return false
            } else {
                UserDefaults.standard.set(counter + 1, forKey: showNFCSwipeHintCounter)
                return true
            }
        }
    }
    
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
    
    static var lastWhatsNewVersionShown : String? {
        get {
            return UserDefaults.standard.string(forKey: whatsNewVersion)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: whatsNewVersion)
        }
    }
    
    static var isBypassTouchEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: bypassTouch)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: bypassTouch)
        }
    }
    
    static var isNFCOnAppLaunchEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: nfcOnAppLaunch)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: nfcOnAppLaunch)
        }
    }
}
