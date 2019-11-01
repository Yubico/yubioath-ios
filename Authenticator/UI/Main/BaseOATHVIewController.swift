//
//  BaseOATHVIewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class BaseOATHVIewController: UITableViewController, CredentialViewModelDelegate {
    let viewModel = YubikitManagerModel()
    let secureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    let passwordPreferences = PasswordPreferences()
    var keyIdentifier: String? {
        get {
            if let accessoryDescription = YubiKitManager.shared.accessorySession.accessoryDescription {
                return accessoryDescription.serialNumber
            } else {
               if #available(iOS 13.0, *) {
                    return YubiKitManager.shared.nfcSession.tagDescription?.identifier.hex
                } else {
                    return nil
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // register cell identifiers
        viewModel.delegate = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // notify view model that view in foreground and it can resume operations
        viewModel.resume()
        
        // update view in case if state has changed
        self.tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // prevent view model to work in background
        // we want to operate with key only in foreground
        viewModel.pause()
        super.viewWillDisappear(animated)
    }
    
    @objc func activateNfc() {
        guard #available(iOS 13.0, *) else {
            fatalError()
        }
        if YubiKitManager.shared.nfcSession.iso7816SessionState != .closed {
            YubiKitManager.shared.nfcSession.stopIso7816Session()
        }
        YubiKitManager.shared.nfcSession.startIso7816Session()
    }
       
//
// MARK: - CredentialViewModelDelegate
//
    func onError(error: Error) {
        let errorCode = (error as NSError).code;
        // save key identifier in local variable so that it can be accessed when save password is prompted
        let keyIdentifier = self.keyIdentifier
        
        if errorCode == YKFKeyOATHErrorCode.authenticationRequired.rawValue || errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue {
            // if we saved password in secure store then we can try to authenticate with it
            // in case if we fail we keep the same logic as if we don't have stored password
            if errorCode == YKFKeyOATHErrorCode.authenticationRequired.rawValue && passwordPreferences.useSavedPassword() {
                if let passwordKey = keyIdentifier {
                    do {
                        if let password = try self.secureStore.getValue(for: passwordKey) {
                            self.viewModel.validate(password: password)
                            // doing early return for this special case because
                            // we need to keep active session for NFC
                            // so that validation happens during the same connection
                            // all other cases will close active NFC connection
                            return
                        }
                    } catch (let e) {
                        print("No stored password for this key: \(e.localizedDescription)")
                    }
                } else {
                    print("Failed to get key identifier to get password, so user will be prompted for password")
                }
            }
            
            let message = errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue ? "Provided password was wrong" : "To prevent anauthorized access YubiKey is protected with a password"
                self.showPasswordPrompt(preferences: passwordPreferences, message: message, inputHandler: {  [weak self] (password) -> Void in
                    guard let self = self else {
                        return
                    }
                    self.viewModel.validate(password: password)
                    guard let passwordKey = keyIdentifier else {
                        self.showAlertDialog(title: "Password was not saved", message: "Couldn't detect key uinique device Id")
                        return
                    }
                    if self.passwordPreferences.useSavedPassword() {
                        do {
                          try self.secureStore.setValue(password, for: passwordKey)
                        } catch (let e) {
                            self.passwordPreferences.resetPasswordPreference()
                            self.showAlertDialog(title: "Password was not saved", message: e.localizedDescription)
                        }
                    }
                }, cancelHandler: {  [weak self] () -> Void in
                    self?.tableView.reloadData()
                })
        } else {
            // TODO: think about better error dialog for case when no connection (future NFC support - ask to tap over NFC)
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
                guard #available(iOS 13.0, *) else {
                    fatalError()
                }
                
                let nfcHandler = { () -> Void in
                    YubiKitManager.shared.nfcSession.startIso7816Session()
                }
                
                if case KeySessionError.noOathService = error {
                    self.showAlertDialog(title: "", message: "Plug-in your YubiKey to refresh credentials or activate NFC reading in application", nfcHandler: nfcHandler)
                } else {
                    self.showAlertDialog(title: "Error occured", message: error.localizedDescription)
                }
            } else {
                self.showAlertDialog(title: "Error occured", message: error.localizedDescription)
            }
        }

        if YubiKitDeviceCapabilities.supportsISO7816NFCTags && viewModel.isQueueEmpty() && YubiKitManager.shared.nfcSession.iso7816SessionState != .closed{
            guard #available(iOS 13.0, *) else {
                fatalError()
            }

            YubiKitManager.shared.nfcSession.stopIso7816Session()
        }
    }
    
    func onOperationCompleted(operation: OperationName) {
        switch operation {
        case .setCode:
            self.showAlertDialog(title: "Success", message: "The password has been successfully set") { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            }
        case .reset:
            self.showAlertDialog(title: "Success", message: "The application has been successfully reset") { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
                self?.tableView.reloadData()
            }
        default:
            break
        }
        
        if #available(iOS 13.0, *) {
            if viewModel.isQueueEmpty() && YubiKitManager.shared.nfcSession.iso7816SessionState != .closed {
                YubiKitManager.shared.nfcSession.stopIso7816Session()
            }
        }
    }
    
    func onTouchRequired() {
        self.displayToast(message: "Touch your YubiKey")
    }    
}
