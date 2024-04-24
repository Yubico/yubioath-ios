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

extension UIViewController {
    static let PasswordUserDefaultsKey = "PasswordSaveType"
 
    /*! Show error dialog to notify if some operation couldn't be executed
     */
    func showAlertDialog(title: String, message: String? = nil, nfcHandler: (() -> Void)? = nil, okHandler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let cancel = UIAlertAction(title: String(localized: "OK"), style: .cancel) { (action) -> Void in
                okHandler?()
            }
            
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags && nfcHandler != nil {
                let activate = UIAlertAction(title: String(localized: "Activate NFC", comment: "Password save type activate NFC"), style: .default) { (action) -> Void in
                    nfcHandler?()
                }
                alertController.addAction(activate)
            }
            alertController.addAction(cancel)
            self.present(alertController, animated: false)
        }
    }
    
    /*! Shows warning with option to cancel operation
     */
    func showWarning(title: String, message: String, okButtonTitle: String, style: UIAlertAction.Style = .destructive, okHandler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let reset = UIAlertAction(title: okButtonTitle, style: style, handler: { (action) -> Void in
                okHandler?()
            })
            let cancel = UIAlertAction(title: String(localized: "Cancel"), style: .cancel, handler: nil)
            alertController.addAction(reset)
            alertController.addAction(cancel)
            
            self.present(alertController, animated: false)
        }
    }
    
}
