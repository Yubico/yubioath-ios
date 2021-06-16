//
//  YubiKeyConfigurationController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-28.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import UIKit

class OATHConfigurationController: UITableViewController {
    
    @IBOutlet weak var removePasswordTableCell: UITableViewCell!
    @IBOutlet weak var setPasswordTableCell: UITableViewCell!

    var passwordStatusViewModel: PasswordStatusViewModel? = nil
    var passwordConfigurationViewModel: PasswordConfigurationViewModel? = nil
    var passwordStatus: PasswordStatusViewModel.PasswordStatus = .unknown
    
    var passwordPreferences = PasswordPreferences()
    var secureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    
    @IBAction func unwindToKeyConfiguration(segue: UIStoryboardSegue) {
        start()
    }
    
    deinit {
        print("Deinit OATHConfigurationController")
    }
    
    func start() {
        passwordConfigurationViewModel = nil
        passwordStatus = .unknown
        passwordStatusViewModel = PasswordStatusViewModel()
        passwordStatusViewModel?.subscribeToPasswordStatus { [weak self] passwordStatus in
            self?.passwordStatus = passwordStatus
            DispatchQueue.main.async {
                self?.tableView.reloadData()
            }
        }
    }
    
    func pause() {
        passwordStatusViewModel = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pause()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell == removePasswordTableCell && self.passwordStatus == .noPassword {
            return 0
        } else {
            return 42
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell == setPasswordTableCell {
            cell.textLabel?.text = self.passwordStatus == .noPassword ? "Set password" : "Change password"
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 1):
            self.showWarning(title: "Remove password", message: "Remove password for this YubiKey?", okButtonTitle: "Remove password") { [weak self] () -> Void in
                self?.removeYubiKeyPassword(currentPassword: nil)
            }
        case (1, 0):
            let alert = UIAlertController(title: "Not implemented yet", message: nil, completion: {})
            self.present(alert, animated: true, completion: nil)
        case (2, 0):
            self.showWarning(title: "Clear stored passwords?", message: "If you have set a password on any of your YubiKeys you will be prompted for it the next time you use those YubiKeys on this Yubico Authenticator.", okButtonTitle: "Clear") { [weak self] () -> Void in
                self?.removeStoredPasswords()
            }
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        pause()
    }
    
    // MARK: - private helper methods
    
    private func removeYubiKeyPassword(currentPassword: String?) {
        pause()
        guard let passwordConfigurationViewModel = passwordConfigurationViewModel else {
            passwordConfigurationViewModel = PasswordConfigurationViewModel()
            removeYubiKeyPassword(currentPassword: currentPassword)
            return
        }
        passwordConfigurationViewModel.removePassword(password: currentPassword, completion: { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self.start()
                    if let message = message {
                        let alert = UIAlertController(title: message)
                        self.present(alert, animated: true, completion: nil)
                    }
                case .authenticationRequired:
                    let authenticationAlert = UIAlertController(passwordEntryType: .password) { currentPassword in
                        guard let currentPassword = currentPassword else {
                            return
                        }
                        self.removeYubiKeyPassword(currentPassword: currentPassword)
                    }
                    self.present(authenticationAlert, animated: true, completion: nil)
                case .wrongPassword:
                    let authenticationAlert = UIAlertController(passwordEntryType: .retryPassword) { currentPassword in
                        guard let currentPassword = currentPassword else {
                            return
                        }
                        self.removeYubiKeyPassword(currentPassword: currentPassword)
                    }
                    self.present(authenticationAlert, animated: true, completion: nil)
                case .failure(let errorMessage):
                    self.start()
                    if let message = errorMessage {
                        let alert = UIAlertController(title: message)
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        })
    }
    
    private func removeStoredPasswords() {
        passwordPreferences.resetPasswordPreferenceForAll()
        do {
            try secureStore.removeAllValues()
            self.showAlertDialog(title: "Success", message: "Stored passwords have been cleared from this phone.", okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        } catch let e {
            self.showAlertDialog(title: "Failed to clear stored passwords.", message: e.localizedDescription, okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        }
    }
}

