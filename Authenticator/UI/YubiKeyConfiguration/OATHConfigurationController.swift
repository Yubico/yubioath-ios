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
import UIKit

class OATHConfigurationController: UITableViewController {
    
    @IBOutlet weak var removePasswordTableCell: UITableViewCell!
    @IBOutlet weak var clearPasswordsOnDeviceLabel: UILabel!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearPasswordsOnDeviceLabel.text = "\(String(localized: "Clear passwords saved on", comment: "Substring from 'Clear passwords saved on [iPad/iPhone]. This will prompt for a passowrd next time a password protected YubiKey is used.'.")) \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"). \(String(localized: "This will prompt for a password next time a password protected YubiKey is used", comment:  "Substring from 'Clear passwords saved on [iPad/iPhone]. This will prompt for a passowrd next time a password protected YubiKey is used.'."))."
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
            self.showWarning(title: String(localized: "Remove password", comment: "Remove password alert title"),
                             message: String(localized: "Remove password for this YubiKey?", comment: "Remove password alert message"),
                             okButtonTitle: String(localized: "Remove password", comment: "Remove password alert button")) { [weak self] () -> Void in
                self?.removeYubiKeyPassword(currentPassword: nil)
            }
        case (1, 1):
            self.showWarning(title: String(localized: "Clear passwords?", comment: "Clear password alert title"),
                             message: String(localized: "Clear passwords saved on iPhone. This will prompt for a password next time a password protected YubiKey is used.", comment: "Clear password alert message"),
                             okButtonTitle: String(localized: "Clear", comment: "Clear password alert button")) { [weak self] () -> Void in
                self?.removeStoredPasswords()
            }
        case (2, 1):
            print("removed")
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
            self.showAlertDialog(title: String(localized: "Success", comment: "Clear passwords confirmation alert title"),
                                 message: String(localized: "Stored passwords have been cleared from this phone.", comment: "Clear passwords confirmation alert message"),
                                 okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        } catch {
            self.showAlertDialog(title: String(localized: "Failed to clear passwords", comment: "Clear passwords failure alert title"),
                                 message: error.localizedDescription,
                                 okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        }
    }
}
