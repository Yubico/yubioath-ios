//
//  UIAlertController+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-04.
//  Copyright © 2021 Yubico. All rights reserved.
//

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
                  preferredStyle: .actionSheet)

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
        
        // The action sheet requires a presentation popover on iPad.
        if UIDevice.current.userInterfaceIdiom == .pad {
            self.modalPresentationStyle = .popover
            if let popoverController = self.popoverPresentationController {
//                popoverController.sourceView = self.view.superview
//                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
        }
    }
}
