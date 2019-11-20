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
    
    func activateNfc() {
        viewModel.startNfc()
    }
       
//
// MARK: - CredentialViewModelDelegate
//
    /*! Delegate method that invoked when any operation failed
     * Operation could be from YubiKit operations (e.g. calculate) or QR scanning (e.g. scan code)
     */
    func onError(error: Error) {
        let errorCode = (error as NSError).code;
        // save key identifier in local variable so that it can be accessed when save password is prompted
        let keyIdentifier = self.viewModel.keyIdentifier
        
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
            
            let message = errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue ? "Incorrect password. Please try again" : "To prevent unauthorized access YubiKey is protected with a password"
                self.showPasswordPrompt(preferences: passwordPreferences, message: message, inputHandler: {  [weak self] (password) -> Void in
                    guard let self = self else {
                        return
                    }
                    self.viewModel.validate(password: password)
                    if self.passwordPreferences.useSavedPassword() {
                        do {
                            // in case if we don't have connection (NFC) our keyIdentifier will be unknown, we put into temporary slot on KeyChain
                            // and move it when we validated password and got keyIdentifier in connection
                            try self.secureStore.setValue(password, for: keyIdentifier)
                        } catch (let e) {
                            self.passwordPreferences.resetPasswordPreference()
                            self.showAlertDialog(title: "Password was not saved", message: e.localizedDescription)
                        }
                    }
                }, cancelHandler: {  [weak self] () -> Void in
                    self?.tableView.reloadData()
                })
        } else {
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags, case KeySessionError.noOathService = error {
                guard #available(iOS 13.0, *) else {
                    fatalError()
                }
                
                if SettingsConfig.showNoServiceWarning {
                    self.showAlertDialog(title: "", message: "Plug-in your YubiKey or activate NFC reading in application", nfcHandler: {[weak self] () -> Void in
                        self?.activateNfc()
                    })
                } else {
                    // activate NFC by default, assuming that if key not plugged in, user uses NFC
                    activateNfc()
                }
            } else {
                print("Error code: \(String(format:"0x%02X", errorCode))")
                self.showAlertDialog(title: "Error occured", message: error.localizedDescription)
            }
        }

        viewModel.stopNfc()
    }
    
    /*! Delegate method that invoked when any operation succeeded
     * Operation could be from YubiKit (e.g. calculate) or local (e.g. filter)
     */
    func onOperationCompleted(operation: OperationName) {
        switch operation {
        case .validate:
            if self.passwordPreferences.useSavedPassword(), let keyIdentifier = self.viewModel.keyIdentifier {
                do {
                    try self.secureStore.moveValue(to: keyIdentifier)
                } catch (let e) {
                    self.showAlertDialog(title: "Password was not saved", message: e.localizedDescription)
                }
            }
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
        
        viewModel.stopNfc()
    }
    
    /*! Delegate method invoked when we need to retry if user approves */
    func onOperationRetry(operation: OATHOperation) {
        // currently only put operation can have conditioned retry
        guard operation.operationName == .put else {
            return
        }
        guard SettingsConfig.showBackupWarning else {
            return
        }
        let backupText = "Secrets are stored safely on YubiKey. Backups can only be created during set up. \nDo you want to add this account to another key for backup? " + (viewModel.keyPluggedIn ? "Unplug your inserted key and insert another one, then tap Backup button" : "")
        self.showWarning(title: "Account added. Create a backup?", message: backupText, okButtonTitle: "Backup", style: .default) { [weak self] () -> Void in
            guard let self = self else {
                return
            }
            self.viewModel.onRetry(operation: operation, suspendQueue: false)
        }
    }
    
    func onTouchRequired() {
        self.displayToast(message: "Touch your YubiKey")
    }
}
