//
//  PasswordPromptController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/31/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UIViewController {
    enum KeyType {
        case none
        case accessory
        case nfc
    }
    
    static let PassowrdUserDefaultsKey = "PasswordSaveType"
    
    /*! Shows view with edit text field amd returns input text within inputHandler
     */
    func showPasswordPrompt(preferences: PasswordPreferences, message: String, inputHandler: ((String) -> Void)? = nil, cancelHandler: (() -> Void)? = nil) {
        var inputTextField: UITextField?
        let alertController = UIAlertController(title: "Unlock YubiKey", message: message, preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            if !preferences.neverSavePassword() {
                self.showPasswordSaveSheet() { (saveType) -> Void in
                    preferences.setPasswordPreference(saveType: saveType)
                    inputHandler?(inputTextField?.text ?? "")
                }
            } else  {
                DispatchQueue.main.async {
                    inputHandler?(inputTextField?.text ?? "")
                }
            }
        })
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
            cancelHandler?()
        }
        alertController.addTextField { (textField) -> Void in
            // Here you can configure the text field (eg: make it secure, add a placeholder, etc)
            inputTextField = textField
            inputTextField?.isSecureTextEntry = true
        }
        
        alertController.addAction(ok)
        alertController.addAction(cancel)

        self.present(alertController, animated: false)
    }
    
    /*! Shows bottom sheet with options whether to save password or not
     */
    private func showPasswordSaveSheet(inputHandler: ((PasswordSaveType) -> Void)? = nil) {
        let actionSheet = UIAlertController(title: "Would you like to save this password for YubiKey for next usage in this application?", message: "You can remove saved password in Settings.", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Save Password", style: .default, handler: { (action) -> Void in
            DispatchQueue.main.async {
                inputHandler?(.save)
            }
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Never for this application", style: .default, handler: { (action) -> Void in
            DispatchQueue.main.async {
                inputHandler?(.never)
            }
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Not now", style: .cancel, handler: { [weak self] (action) in
            guard let self = self else {
                return
            }

            self.dismiss(animated: true, completion: nil)
            
            DispatchQueue.main.async {
                inputHandler?(.none)
            }
        }))
        
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

    /*! Shows bottom sheet with option whether user wants to activate NFC or prefer to continue with plugged in key
     */
    func showTrasportSelectionSheet(title: String, message: String, anchorView:UIView, inputHandler: ((KeyType) -> Void)? = nil) {
        let actionSheet = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            actionSheet.addAction(UIAlertAction(title: "Scan my key - Over NFC", style: .default, handler: { (action) -> Void in
                guard #available(iOS 13.0, *) else {
                    fatalError()
                }

                DispatchQueue.main.async {
                    inputHandler?(.nfc)
                }
            }))
        }
        
        actionSheet.addAction(UIAlertAction(title: "Plug my key - From MFi key", style: .default, handler: { (action) -> Void in
            DispatchQueue.main.async {
                inputHandler?(.accessory)
            }
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] (action) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.dismiss(animated: true, completion: nil)
        }))
        
        // The action sheet requires a presentation popover on iPad.
        if UIDevice.current.userInterfaceIdiom == .pad {
            actionSheet.modalPresentationStyle = .popover
            if let presentationController = actionSheet.popoverPresentationController {
                presentationController.sourceView = anchorView
                presentationController.sourceRect = anchorView.bounds
            }
        }
        
        present(actionSheet, animated: true, completion: nil)
    }

    /*! Show error dialog to notify if some operation couldn't be executed
     */
    func showAlertDialog(title: String, message: String, nfcHandler: (() -> Void)? = nil, okHandler: (() -> Void)? = nil) {
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
        
        let reset = UIAlertAction(title: okButtonTitle, style: .destructive, handler: { (action) -> Void in
            okHandler?()
        })
        let cancel = UIAlertAction(title: "Cancel", style: style) { (action) -> Void in }
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
