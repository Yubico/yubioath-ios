//
//  BaseOATHVIewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class BaseOATHVIewController: UITableViewController, CredentialViewModelDelegate {
    let viewModel = OATHViewModel()
    let passwordPreferences = PasswordPreferences()
    var passwordCache = PasswordCache()
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
        // not sure we will need this
        print("Got error: \(error)")
    }
    
    /*! Delegate method that invoked when any operation succeeded
     * Operation could be from YubiKit (e.g. calculate) or local (e.g. filter)
     */
    func onOperationCompleted(operation: OperationName) {
        switch operation {
        case .setCode:
            self.showAlertDialog(title: "Success", message: "The password has been successfully set", okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        case .reset:
            self.showAlertDialog(title: "Success", message: "The application has been successfully reset", okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
                self?.tableView.reloadData()
            })
        case .getConfig:
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "ShowTagSettings", sender: self)
            }
        case .getKeyVersion:
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "ShowDeviceInfo", sender: self)
            }
        case .calculateAll, .cleanup, .filter:
            self.tableView.reloadData()
        default:
            // other operations do not change list of credentials
            break
        }
        
        //self.viewModel.stopNfc()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == .tagConfig {
            let destinationNavigationController = segue.destination as! UINavigationController
            if let deviceInfoViewController = destinationNavigationController.topViewController as? YubiKeyConfigurationConroller, let keyConfig = self.viewModel.cachedKeyConfig {
                deviceInfoViewController.keyConfiguration = keyConfig
            }
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
    
    func didValidatePassword(_ password: String, forKey key: String) {
        // Cache password in memory
        passwordCache.setPassword(password, forKey: key)
        
        // Check if we should save password in keychain
        if !self.passwordPreferences.neverSavePassword(keyIdentifier: key) {
            self.secureStore.getValue(for: key) { result in
                let currentPassword = try? result.get()
                if password != currentPassword {
                    let passwordActionSheet = UIAlertController(passwordPreferences: self.passwordPreferences) { type in
                        self.passwordPreferences.setPasswordPreference(saveType: type, keyIdentifier: key)
                        if self.passwordPreferences.useSavedPassword(keyIdentifier: key) || self.passwordPreferences.useScreenLock(keyIdentifier: key) {
                            do {
                                try self.secureStore.setValue(password, useAuthentication: self.passwordPreferences.useScreenLock(keyIdentifier: key), for: key)
                            } catch let e {
                                self.passwordPreferences.resetPasswordPreference(keyIdentifier: key)
                                self.showAlertDialog(title: "Password was not saved", message: e.localizedDescription)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.present(passwordActionSheet, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func cachedPasswordFor(keyId: String, completion: @escaping (String?) -> Void) {
        if let password = passwordCache.password(forKey: keyId) {
            completion(password)
            return
        }
        self.secureStore.getValue(for: keyId) { result in
            let password = try? result.get()
            completion(password)
            return
        }
    }
    
    func passwordFor(keyId: String, isPasswordEntryRetry: Bool, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let passwordEntryAlert = UIAlertController(passwordEntryType: isPasswordEntryRetry ? .retryPassword : .password) { password in
                completion(password)
            }
            self.present(passwordEntryAlert, animated: true)
        }
    }
}
