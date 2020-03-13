//
//  SettingsViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/7/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit
import FirebaseAnalytics

class SettingsViewController: BaseOATHVIewController {
    private var allowKeyOperations = YubiKitDeviceCapabilities.supportsISO7816NFCTags
    
    private var appVersion = UIApplication.appVersion
    private var systemVersion = UIDevice().systemVersion
    private var keySessionObserver: KeySessionObserver!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.keySessionObserver = KeySessionObserver(accessoryDelegate: self, nfcDlegate: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.keySessionObserver.observeSessionState = false
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch (indexPath.section, indexPath.row) {
        case (3, 0):
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stboard = UIStoryboard(name: "Main", bundle: nil)
        let webVC = stboard.instantiateViewController(withIdentifier: "WebViewController") as! WebViewController
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
                if !self.viewModel.keyPluggedIn {
                    self.viewModel.getKeyVersion()
                    Analytics.logEvent("show_device_info", parameters: ["device" : "nfc"])
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.performSegue(withIdentifier: "ShowDeviceInfo", sender: self)
                        Analytics.logEvent("show_device_info", parameters: ["device" : "5ci"])
                }
            }
            
        case (0, 2):
            self.showWarning(title: "Reset OATH application?", message: "This will delete all accounts and restore factory defaults of your YubiKey.", okButtonTitle: "Reset") { [weak self] () -> Void in
                self?.viewModel.reset()
            }
        case (1, 0):
            self.showWarning(title: "Clear stored passwords?", message: "If you have set a password on any of your YubiKeys you will be prompted for it the next time you use those YubiKeys on this Yubico Authenticator.", okButtonTitle: "Clear") { [weak self] () -> Void in
                self?.removeStoredPasswords()
                Analytics.logEvent("clear_stored_passwords", parameters: nil)
            }
        case (1, 1):
            // Workaround for modal segue bug: segue is very slow and takes up to 6sec to appear.
            // Here is a link: https://stackoverflow.com/questions/28509252/performseguewithidentifier-very-slow-when-segue-is-modal
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "StartFRE", sender: self)
                Analytics.logEvent("tutorial_start_settings", parameters: nil)
            }
        case (2, 0):
            webVC.url = URL(string: "https://www.yubico.com/support/terms-conditions/yubico-license-agreement/")
            self.navigationController?.pushViewController(webVC, animated: true)
            Analytics.logEvent("terms_condirions", parameters: nil)
        case (2, 1):
            webVC.url = URL(string: "https://www.yubico.com/support/terms-conditions/privacy-notice/")
            self.navigationController?.pushViewController(webVC, animated: true)
            Analytics.logEvent("privacy_policy", parameters: nil)
        case (2, 2):
            var title = "[iOS Authenticator] \(appVersion), iOS\(systemVersion)"
            if let description = viewModel.keyDescription {
                title += ", key \(description.firmwareRevision)"
            }
            
            title = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "[iOSAuthenticator]"
            webVC.url = URL(string: "http://support.yubico.com/support/tickets/new?setField-helpdesk_ticket_subject=\(title)")
            self.navigationController?.pushViewController(webVC, animated: true)
            Analytics.logEvent("support", parameters: nil)
            
        default:
            break
        }
    }
    
    // MARK: - private helper methods
    
    private func removeStoredPasswords() {
        passwordPreferences.resetPasswordPreferenceForAll()
        do {
            try secureStore.removeAllValues()
            self.showAlertDialog(title: "Success", message: "Stored passwords have been cleared from this phone.") { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            }
        } catch let e {
            self.showAlertDialog(title: "Error happend during cleaning up passwords.", message: e.localizedDescription) { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
}

// MARK: - Key Session Observer

extension SettingsViewController: AccessorySessionObserverDelegate {
    func accessorySessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFAccessorySessionState) {
        self.tableView.reloadData()
    }
}

extension SettingsViewController: NfcSessionObserverDelegate {
    func nfcSessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFNFCISO7816SessionState) {
        viewModel.nfcStateChanged(state: state)
        if state == .open {
            viewModel.resume()
        }
    }
}
