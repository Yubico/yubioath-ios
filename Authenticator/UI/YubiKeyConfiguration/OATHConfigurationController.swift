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

    var passwordStatusViewModel: PasswordStatusViewModel? = nil
    var passwordConfigurationViewModel: PasswordConfigurationViewModel? = nil
    var passwordStatus: PasswordStatusViewModel.PasswordStatus = .unknown
    
    var passwordPreferences = PasswordPreferences()
    var secureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    
    var resetViewModel: ResetOATHViewModel?
    
    deinit {
        print("Deinit OATHConfigurationController")
    }
    
    @IBAction func unwind( _ seg: UIStoryboardSegue) {
        start()
    }
    
    func start() {
        resetViewModel = nil
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
            return UITableView.automaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 2):
            self.showWarning(title: "Remove password", message: "Remove password for this YubiKey?", okButtonTitle: "Remove password") { [weak self] () -> Void in
                self?.removeYubiKeyPassword(currentPassword: nil)
            }
        case (1, 1):
            self.showWarning(title: "Clear passwords?", message: "Clear passwords saved on iPhone. This will prompt for a password next time a password protected YubiKey is used.", okButtonTitle: "Clear") { [weak self] () -> Void in
                self?.removeStoredPasswords()
            }
        case (2, 1):
            self.showWarning(title: "Reset YubiKey?", message: "This will delete all accounts and restore factory defaults of your YubiKey.", okButtonTitle: "Reset") { [weak self] () -> Void in
                self?.resetOATH()
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
            self.showAlertDialog(title: "Failed to clear passwords.", message: e.localizedDescription, okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        }
    }
    
    private func resetOATH() {
        pause()
        Thread.sleep(forTimeInterval: TimeInterval(0.1)) // This is a kludge to let the delegates switch to the correct one
        resetViewModel = ResetOATHViewModel()
        resetViewModel?.reset { result in
            DispatchQueue.main.async {
                self.start()
                switch result {
                case .success(let message):
                    if let message = message {
                        self.showAlertDialog(title: "Reset complete", message: message)
                    }
                case .failure(let error):
                    if let message = error {
                        self.showAlertDialog(title: "Failed to reset YubiKey", message: message)
                    }
                }
            }
        }
    }
}
