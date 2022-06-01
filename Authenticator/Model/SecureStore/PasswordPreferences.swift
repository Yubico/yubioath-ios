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
import LocalAuthentication

enum AuthenticationType {
    case touchId
    case faceId
    case passcode
    case none
    
    var title: String {
        switch self {
        case .touchId:
            return "Touch ID"
        case .faceId:
            return "Face ID"
        case .passcode:
            return "Passcode"
        default:
            return ""
        }
    }
}

enum PasswordSaveType: Int {
    case none = 0
    case never
    case save
    case lock
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
