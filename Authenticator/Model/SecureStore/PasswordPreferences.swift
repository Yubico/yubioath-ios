//
//  PasswordPreferences.swift
//  Authenticator
//
//  Created by Irina Makhalova on 10/3/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation
import LocalAuthentication

enum PasswordSaveType: Int {
    case none = 0
    case never
    case save
    case lock
    
    var title: String {
        switch self {
        case .none:
            return "not now"
        case .never:
            return "never"
        case .save:
            return "save"
        case .lock:
            return "protect"
        }
    }
}

/*! Allows to store user selection of preferences: whether to save password or not.
 Using UserDefaults as permanent storage
 */
class PasswordPreferences {

    /* This method returns what biometric authentiacation type set on user's device.
    canEvaluatePolicy should be called before getting the biometryType.
    */
    func evaluatedAuthenticationType() -> AuthenticationType {
        let context = LAContext()
        var errorPolicy: NSError?
        var errorBiometricPolicy: NSError?
        
        let hasAuthentication = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &errorPolicy)
        let hasBiometricAuthentication = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &errorBiometricPolicy)
        
        if let error = errorPolicy {
            print("Authentication policy error: " + String(describing: error.localizedDescription))
        }
        
        if let error = errorBiometricPolicy {
            print("Biometric policy error: " + String(describing: error.localizedDescription))
        }
        
        if !hasAuthentication {
            return .none
        }

        if !hasBiometricAuthentication {
            return .passcode
        }
        
        if #available(iOS 11.0, *) {
            return context.biometryType == .faceID ? .faceId : .touchId
        }

        return .touchId
    }
    
    func neverSavePassword(keyIdentifier: String) -> Bool {
        return UserDefaults.standard.integer(forKey: UIViewController.PasswordUserDefaultsKey + keyIdentifier) == PasswordSaveType.never.rawValue
    }

    func useSavedPassword(keyIdentifier: String) -> Bool {
        let savedPreference = UserDefaults.standard.integer(forKey: UIViewController.PasswordUserDefaultsKey + keyIdentifier)
        return savedPreference == PasswordSaveType.save.rawValue
    }
    
    func useScreenLock(keyIdentifier: String) -> Bool {
        let savedPreference = UserDefaults.standard.integer(forKey: UIViewController.PasswordUserDefaultsKey + keyIdentifier)
        return savedPreference == PasswordSaveType.lock.rawValue
    }
    
    func setPasswordPreference(saveType: PasswordSaveType, keyIdentifier: String) {
        UserDefaults.standard.set(saveType.rawValue, forKey: UIViewController.PasswordUserDefaultsKey + keyIdentifier)
    }
    
    func resetPasswordPreference(keyIdentifier: String) {
        UserDefaults.standard.set(PasswordSaveType.none.rawValue, forKey: UIViewController.PasswordUserDefaultsKey + keyIdentifier)
    }
    
    func resetPasswordPreferenceForAll() {
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.starts(with: UIViewController.PasswordUserDefaultsKey) {
                UserDefaults.standard.set(PasswordSaveType.none.rawValue, forKey: key)
            }
        }
    }
}
