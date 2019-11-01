//
//  StorePreferences.swift
//  Authenticator
//
//  Created by Irina Makhalova on 10/3/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

enum PasswordSaveType : Int {
    case none = 0
    case never = 1
    case save = 2
}

/*! Allows to store user selection of preferences: whether to save password or not.
 Using UserDefaults as permanent storage
 */
class PasswordPreferences {
    
    func neverSavePassword() -> Bool {
        return UserDefaults.standard.integer(forKey: UIViewController.PassowrdUserDefaultsKey) == PasswordSaveType.never.rawValue
    }

    func useSavedPassword() -> Bool {
        return UserDefaults.standard.integer(forKey: UIViewController.PassowrdUserDefaultsKey) == PasswordSaveType.save.rawValue
    }
    
    func setPasswordPreference(saveType: PasswordSaveType) {
        UserDefaults.standard.set(saveType.rawValue, forKey: UIViewController.PassowrdUserDefaultsKey)
    }
    
    func resetPasswordPreference() {
        UserDefaults.standard.set(PasswordSaveType.none.rawValue, forKey: UIViewController.PassowrdUserDefaultsKey)
    }
}
