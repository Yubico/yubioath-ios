/*
 * Copyright (C) 2022 Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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
}
