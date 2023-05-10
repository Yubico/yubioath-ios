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
    static private let nfcOnOTPLaunch = "nfcOnOTPLaunch"
    static private let copyOTP = "copyOTP"
    
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
    
    static var isNFCOnOTPLaunchEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: nfcOnOTPLaunch)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: nfcOnOTPLaunch)
        }
    }
    
    static var isCopyOTPEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: copyOTP)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: copyOTP)
        }
    }
}
