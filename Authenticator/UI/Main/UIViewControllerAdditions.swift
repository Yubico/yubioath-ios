//
//  UIViewControllerAdditions.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/31/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation
import LocalAuthentication

extension UIViewController {
    static let PasswordUserDefaultsKey = "PasswordSaveType"
    /*! Shows view with edit text field amd returns input text within inputHandler
     */
    func showPasswordPrompt(preferences: PasswordPreferences, keyIdentifier: String, message: String, inputHandler: ((String) -> Void)? = nil, cancelHandler: (() -> Void)? = nil) {
        weak var inputTextField: UITextField?
        let alertController = UIAlertController(title: "Unlock YubiKey", message: message, preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default) { (action) -> Void in
            let passwordText = inputTextField?.text ?? ""
        
            if !preferences.neverSavePassword(keyIdentifier: keyIdentifier) {
                self.showPasswordSaveSheet(preferences: preferences) { (saveType) -> Void in
                    preferences.setPasswordPreference(saveType: saveType, keyIdentifier: keyIdentifier)
                    DispatchQueue.main.async {
                        inputHandler?(passwordText)
                    }
                }
            } else  {
                DispatchQueue.main.async {
                    inputHandler?(passwordText)
                }
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
            cancelHandler?()
        }

        alertController.addTextField { (textField) -> Void in
            inputTextField = textField
            inputTextField?.isSecureTextEntry = true
        }
        
        alertController.addAction(ok)
        alertController.addAction(cancel)

        self.present(alertController, animated: false)
    }
    
    /*! Shows bottom sheet with options whether to save password or not
     */
    private func showPasswordSaveSheet(preferences: PasswordPreferences, inputHandler: ((PasswordSaveType) -> Void)? = nil) {
        let authenticationType = preferences.evaluatedAuthenticationType()
        
        let actionSheet = UIAlertController(title: "Would you like to save this password for YubiKey for next usage in this application?", message: "You can remove saved password in Settings.", preferredStyle: .actionSheet)
        let save = UIAlertAction(title: "Save Password", style: .default) { (action) -> Void in inputHandler?(.save) }
        let biometric = UIAlertAction(title: "Save and protect with \(authenticationType.title)", style: .default) { (action) -> Void in inputHandler?(.lock) }
        let never = UIAlertAction(title: "Never for this application", style: .default) { (action) -> Void in inputHandler?(.never) }
        let notNow = UIAlertAction(title: "Not now", style: .cancel) { [weak self] (action) in
            guard let self = self else {
                return
            }
            self.dismiss(animated: true, completion: nil)
            inputHandler?(.none)
        }
        
        actionSheet.addAction(save)

        if authenticationType != .none {
            actionSheet.addAction(biometric)
        }

        actionSheet.addAction(never)
        actionSheet.addAction(notNow)
        
        // The action sheet requires a presentation popover on iPad.
        if UIDevice.current.userInterfaceIdiom == .pad {
            actionSheet.modalPresentationStyle = .popover
            if let popoverController = actionSheet.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
        }
        
        self.present(actionSheet, animated: true, completion: nil)
    }

    /*! Show error dialog to notify if some operation couldn't be executed
     */
    func showAlertDialog(title: String, message: String? = nil, nfcHandler: (() -> Void)? = nil, okHandler: (() -> Void)? = nil) {
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
    
    /*! Shows warning with option to cancel operation
     */
    func showWarning(title: String, message: String, okButtonTitle: String, style: UIAlertAction.Style = .destructive, okHandler: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let reset = UIAlertAction(title: okButtonTitle, style: style, handler: { (action) -> Void in
            okHandler?()
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(reset)
        alertController.addAction(cancel)
        
        self.present(alertController, animated: false)
    }
    
    /*! Shows small toast/text view on the bottom of screen to notify that something has happened (doesn't require user interaction)
     */
    func displayToast(message: String) {
        guard let keyWindow = UIApplication.shared.keyWindow else {
            return
        }
        
        // TODO: calculate width dynamically depending on message
        let toastView = UILabel(frame: CGRect(x: 0, y: 0, width: keyWindow.frame.size.width*3.0/4.0, height: 50.0))
        toastView.text = message;
        toastView.numberOfLines = 0
        toastView.lineBreakMode = .byWordWrapping
        toastView.textAlignment = .center;
        toastView.layer.cornerRadius = 10;
        toastView.layer.masksToBounds = true;
        toastView.textColor = UIColor.white
        toastView.backgroundColor = UIColor.yubiBlue
        toastView.center = CGPoint(x: keyWindow.center.x, y: keyWindow.bounds.height - toastView.bounds.height/2 - keyWindow.layoutMargins.bottom)
        
        keyWindow.addSubview(toastView)
        UIView.animate(withDuration: 5.0, animations: {
            toastView.alpha = 0.0
        }) { (finished) -> Void in
            toastView.removeFromSuperview()
        }
    }

}
