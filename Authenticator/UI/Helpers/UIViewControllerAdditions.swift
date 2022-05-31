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
            let cancel = UIAlertAction(title: "OK", style: .cancel) { (action) -> Void in
                okHandler?()
            }
            
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags && nfcHandler != nil {
                let activate = UIAlertAction(title: "Activate NFC", style: .default) { (action) -> Void in
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
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(reset)
            alertController.addAction(cancel)
            
            self.present(alertController, animated: false)
        }
    }
    
    /*! Shows small toast/text view on the bottom of screen to notify that something has happened (doesn't require user interaction)
     */
    func displayToast(message: String) {
        DispatchQueue.main.async {
            guard let keyWindow = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first else {
                return
            }
            // TODO: calculate width dynamically depending on message
            let toastView = UILabel(frame: CGRect(x: 0, y: 0, width: keyWindow.frame.size.width*3.0/4.0, height: 40.0))
            toastView.text = message;
            toastView.numberOfLines = 0
            toastView.lineBreakMode = .byWordWrapping
            toastView.textAlignment = .center;
            toastView.layer.cornerRadius = 20;
            toastView.layer.masksToBounds = true;
            toastView.textColor = .white
            toastView.font = .preferredFont(forTextStyle: .body)
            toastView.backgroundColor = UIColor.yubiBlue
            toastView.center = CGPoint(x: keyWindow.center.x, y: keyWindow.layoutMargins.top + 14)
            toastView.alpha = 0
            keyWindow.addSubview(toastView)
            UIView.animate(withDuration: 0.2) {
                toastView.alpha = 1
            } completion: { _ in
                UIView.animate(withDuration: 0.7, delay: 1.5) {
                    toastView.alpha = 0.0
                } completion: { _ in
                    toastView.removeFromSuperview()
                }
            }
        }
    }
    
}
