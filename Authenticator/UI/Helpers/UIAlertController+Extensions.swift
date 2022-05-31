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
            message = "To prevent unauthorized access this YubiKey is protected with a password."
        case .retryPassword:
            message = "Incorrect password. Re-enter password."
        }

        self.init(title: "Unlock YubiKey", message: message, preferredStyle: .alert)
        weak var inputTextField: UITextField?
        self.addTextField { textField in
            textField.isSecureTextEntry = true
            inputTextField = textField
        }
        
        let ok = UIAlertAction(title: "OK", style: .default) { _ in
            completion(inputTextField?.text)
        }
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil)
        }
        self.addAction(ok)
        self.addAction(cancel)
    }
    
    convenience init(passwordPreferences preferences: PasswordPreferences, completion: @escaping (PasswordSaveType) -> Void) {
        let authenticationType = preferences.evaluatedAuthenticationType()
        
        self.init(title: "Would you like to save this password for YubiKey for next usage in this application?",
                  message: "You can remove saved password in Settings.",
                  preferredStyle: UIDevice.current.userInterfaceIdiom == .pad ? .alert : .actionSheet)

        let save = UIAlertAction(title: "Save Password", style: .default) { _ in completion(.save) }
        let biometric = UIAlertAction(title: "Save and protect with \(authenticationType.title)", style: .default) { _ in completion(.lock) }
        let never = UIAlertAction(title: "Never for this YubiKey", style: .default) { _ in completion(.never) }
        let notNow = UIAlertAction(title: "Not now", style: .cancel) { _ in
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
