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
    let passwordPreferences = PasswordPreferences()
    let secureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // register cell identifiers
        self.viewModel.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // notify view model that view in foreground and it can resume operations
        self.viewModel.resume()
        
        // update view in case if state has changed
        self.tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // prevent view model to work in background
        // we want to operate with key only in foreground
        self.viewModel.pause()
        super.viewWillDisappear(animated)
    }
    
    func activateNfc() {
        self.viewModel.startNfc()
    }
    
    // MARK: - CredentialViewModelDelegate
    
    /*! Delegate method that invoked when any operation failed
     * Operation could be from YubiKit operations (e.g. calculate) or QR scanning (e.g. scan code)
     */
    func onError(error: Error) {
        let errorCode = (error as NSError).code
        // Save key identifier in local variable so that it can be accessed when save password is prompted.
        let keyIdentifier = self.viewModel.keyIdentifier
        
        if errorCode == YKFKeyOATHErrorCode.authenticationRequired.rawValue || errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue {
            let message = errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue
                ? "Incorrect password. Re-enter password."
                : "To prevent unauthorized access this YubiKey is protected with a password."
            
            // If we saved password in secure store then we can try to authenticate with it.
            // In case of any failure, we keep as if we don't have stored password.
            if let passwordKey = keyIdentifier, self.secureStore.hasValue(for: passwordKey), errorCode == YKFKeyOATHErrorCode.authenticationRequired.rawValue {
                    self.validatePassword(for: passwordKey, with: message)
                    // Doing early return for this special case because
                    // we need to keep active session for NFC
                    // so that validation happens during the same connection
                    // all other cases will close active NFC connection.
                    return
            }
            
            self.showPasswordPrompt(with: message)
            
        } else {
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags, case KeySessionError.noService = error {
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
                if self.viewModel.cachedKeyId == keyIdentifier || self.viewModel.cachedKeyId == nil || keyIdentifier == nil {
                    self.showAlertDialog(title: "Error occurred", message: error.localizedDescription)
                }
            }
        }
        
        self.viewModel.stopNfc()
    }
    
    /* Validates YubiKey password. If password is available in secure storage then use it,
    otherwise shows prompt to user and request password.
    */
    private func validatePassword(for userAccount: String, with message: String) {
        let hasValueProtected = self.secureStore.hasValueProtected(for: userAccount)
        self.secureStore.getValueAsync(
            for: userAccount,
            useAuthentication: hasValueProtected,
            success: { password in
                self.viewModel.validate(password: password)
            },
            failure: { error in
                self.showPasswordPrompt(with: message)
                print("No stored password for this key: \(error.localizedDescription)")
        })
    }
    
    /* Shows password prompt to user with specified message, validates password
    and saves the option (Save password or Save password with biometric protection) selected by user into permanent storage.
    */
    private func showPasswordPrompt(with message: String) {
        if let passwordKey = self.viewModel.keyIdentifier {
            self.showPasswordPrompt(preferences: self.passwordPreferences, keyIdentifier: passwordKey, message: message, inputHandler: {
                [weak self] (password) -> Void in
                guard let self = self else {
                    return
                }
                self.viewModel.validate(password: password)
                if self.passwordPreferences.useSavedPassword(keyIdentifier: passwordKey) || self.passwordPreferences.useScreenLock(keyIdentifier: passwordKey) {
                    do {
                        try self.secureStore.setValue(password, useAuthentication: self.passwordPreferences.useScreenLock(keyIdentifier: passwordKey), for: passwordKey)
                    } catch let e {
                        self.passwordPreferences.resetPasswordPreference(keyIdentifier: passwordKey)
                        self.showAlertDialog(title: "Password was not saved", message: e.localizedDescription)
                    }
                }
            }, cancelHandler: { [weak self] () -> Void in
                self?.tableView.reloadData()
            })
        }
    }
    
    /*! Delegate method that invoked when any operation succeeded
     * Operation could be from YubiKit (e.g. calculate) or local (e.g. filter)
     */
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
        case .getConfig:
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "ShowTagSettings", sender: self)
            }
        case .setConfig:
            if self.viewModel.keyPluggedIn {
                self.showAlertDialog(title: "Note", message: "In order for this setting to apply please unplug and plag back the Ybikey.") { [weak self] () -> Void in
                    self?.dismiss(animated: true, completion: nil)
                }
            }
        case .calculateAll, .cleanup, .filter:
            self.tableView.reloadData()
        default:
            // other operations do not change list of credentials
            break
        }
        
        self.viewModel.stopNfc()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == .tagConfig {
            let destinationNavigationController = segue.destination as! UINavigationController
            if let deviceInfoViewController = destinationNavigationController.topViewController as? TagSwitchViewController {
                deviceInfoViewController.keyConfig = self.viewModel.cachedKeyConfig
            }
        }
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
    
    func onShowToastMessage(message: String) {
        self.displayToast(message: message)
    }
    
    func onCredentialDelete(indexPath: IndexPath) {
        // Removal of last element in section requires to remove the section.
        if self.viewModel.credentials.count == 0 {
            self.tableView.deleteSections([0], with: .fade)
        } else {
            self.tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}
