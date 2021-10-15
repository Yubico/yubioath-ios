//
//  ApplicationSettingsViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-10-13.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

struct ApplicationSettingsViewModel {

    var isBypassTouchEnabled: Bool {
        get {
            return SettingsConfig.isBypassTouchEnabled
        }
        set {
            SettingsConfig.isBypassTouchEnabled = newValue
        }
    }
    
    var isNFCOnAppLaunchEnabled: Bool {
        get {
            return SettingsConfig.isNFCOnAppLaunchEnabled
        }
        set {
            SettingsConfig.isNFCOnAppLaunchEnabled = newValue
        }
    }
}
