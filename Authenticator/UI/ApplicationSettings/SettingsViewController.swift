//
//  SettingsViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/7/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//


// SettingsViewController
//   - start accessory connection when view becomes active and adopt UI
//   -

import UIKit

class SettingsViewController: UITableViewController {
   
    @IBAction func unwindToSettings(segue: UIStoryboardSegue) {
        start()
    }
    
    @IBOutlet weak var removePasswordTableCell: UITableViewCell!
    @IBOutlet weak var setPasswordTableCell: UITableViewCell!
    private let appVersion = UIApplication.appVersion
    private let systemVersion = UIDevice().systemVersion

    var passwordStatusViewModel: PasswordStatusViewModel? = nil
    var passwordConfigurationViewModel: PasswordConfigurationViewModel? = nil
    var passwordStatus: PasswordStatusViewModel.PasswordStatus = .unknown
    
    var passwordPreferences: PasswordPreferences? = nil
    var secureStore: SecureStore? = nil
    
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        start()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pause()
    }
    
    // MARK: - Table view data source
    
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
        
        switch (indexPath.section, indexPath.row) {
        case (3, 1):
            cell.textLabel?.text = "Yubico Authenticator \(self.appVersion)"
        default:
            break
        }
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }
    
    /*
     Reset feature was removed for users due to it's complexity.
     To get to the default state user can manually delete credentials and remove password under Settings.
     To restore this feature, use git history and add a cell to SettingsViewController in the main storyboard.
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stboard = UIStoryboard(name: "Main", bundle: nil)
        let webVC = stboard.instantiateViewController(withIdentifier: "WebViewController") as! WebViewController
        
        switch (indexPath.section, indexPath.row) {
        case (0, 2):
            self.showWarning(title: "Remove password", message: "Remove password for this YubiKey?", okButtonTitle: "Remove password") { [weak self] () -> Void in
                self?.removeYubiKeyPassword(currentPassword: nil)
            }
        case (1, 0):
            self.showWarning(title: "Clear stored passwords?", message: "If you have set a password on any of your YubiKeys you will be prompted for it the next time you use those YubiKeys on this Yubico Authenticator.", okButtonTitle: "Clear") { [weak self] () -> Void in
                self?.removeStoredPasswords()
            }
        case (1, 1):
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "StartFRE", sender: self)
            }
        case (2, 0):
            webVC.url = URL(string: "https://www.yubico.com/support/terms-conditions/yubico-license-agreement/")
            self.navigationController?.pushViewController(webVC, animated: true)
        case (2, 1):
            webVC.url = URL(string: "https://www.yubico.com/support/terms-conditions/privacy-notice/")
            self.navigationController?.pushViewController(webVC, animated: true)
        case (2, 2):
            var title = "[iOS Authenticator] \(appVersion), iOS\(systemVersion)"
            //            if let description = viewModel.keyDescription {
            //                title += ", key \(description.firmwareRevision)"
            //            }
            
            title = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "[iOSAuthenticator]"
            webVC.url = URL(string: "https://support.yubico.com/support/tickets/new?setField-helpdesk_ticket_subject=\(title)")
            self.navigationController?.pushViewController(webVC, animated: true)
            
        case (3, 0):
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "ShowWhatsNew", sender: self)
            }
        default:
            break
        }
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
        passwordPreferences?.resetPasswordPreferenceForAll()
        do {
            try secureStore?.removeAllValues()
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
