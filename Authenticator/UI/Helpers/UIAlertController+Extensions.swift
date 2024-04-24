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

import UIKit

extension UIAlertController {
    
    convenience init(title: String? = nil, message: String? = nil, completion: @escaping (() -> Void) = {}) {
        self.init(title: title,
                  message: message,
                  preferredStyle: .alert)
        let dismiss = UIAlertAction(title: "Ok", style: .default) { [weak self] _ in
            completion()
            self?.dismiss(animated: true, completion: nil)
        }
        self.addAction(dismiss)
    }
    
    enum PasswordEntryType {
        case password
        case retryPassword
    }
    
    convenience init(passwordEntryType type: PasswordEntryType, completion: @escaping (String?) -> Void) {
        let message: String
        switch type {
        case .password:
            message = String(localized: "To prevent unauthorized access this YubiKey is protected with a password.", comment: "OATH password entry enter password")
        case .retryPassword:
            message = String(localized: "Incorrect password. Re-enter password.", comment: "OATH password entry retry")
        }

        self.init(title: String(localized: "Unlock YubiKey", comment: "Password entry unlock message"), message: message, preferredStyle: .alert)
        weak var inputTextField: UITextField?
        self.addTextField { textField in
            textField.isSecureTextEntry = true
            inputTextField = textField
        }
        
        let ok = UIAlertAction(title: String(localized: "OK"), style: .default) { _ in
            completion(inputTextField?.text)
        }
        let cancel = UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
            completion(nil)
        }
        self.addAction(ok)
        self.addAction(cancel)
    }
    
    convenience init(completion: @escaping (PasswordSaveType) -> Void) {
        let authenticationType = PasswordPreferences.evaluatedAuthenticationType()
        
        self.init(title: String(localized: "Would you like to save this password for YubiKey for next usage in this application?", comment: "Password entry save password title"),
                  message: String(localized: "You can remove saved password in Settings.", comment: "Password entry save password message"),
                  preferredStyle: UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet)

        let save = UIAlertAction(title: String(localized: "Save Password", comment: "Password entry save password button"), style: .default) { _ in completion(.save) }
        let biometric = UIAlertAction(title: "\(String(localized: "Save and protect with", comment: "Password entry save substring in 'Save and protect with [save type]'")) \(authenticationType.title)", style: .default) { _ in completion(.lock) }
        let never = UIAlertAction(title: String(localized: "Never for this YubiKey", comment: "Save password alert."), style: .default) { _ in completion(.never) }
        let notNow = UIAlertAction(title: String(localized: "Not now", comment: "Save passsword alert"), style: .cancel) { _ in
            completion(.none)
            self.dismiss(animated: true, completion: nil)
        }
        self.addAction(save)
        if authenticationType != .none {
            self.addAction(biometric)
        }
        self.addAction(never)
        self.addAction(notNow)
    }
}
