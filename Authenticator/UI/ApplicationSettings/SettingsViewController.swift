//
//  SettingsViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/7/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class SettingsViewController: BaseOATHVIewController {
    private var allowKeyOperations = YubiKitDeviceCapabilities.supportsISO7816NFCTags
    
    private var appVersion = UIApplication.appVersion
    private var systemVersion = UIDevice().systemVersion
    private var keySessionObserver: KeySessionObserver!
    
    @IBAction func unwindToSettingsViewController(segue: UIStoryboardSegue) {
        if let sourceViewController = segue.source as? YubiKeyConfigurationConroller, let keyConfiguration = sourceViewController.keyConfiguration {
            self.viewModel.setConfiguration(configuration: keyConfiguration)
        }
    }
    
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
    
    /*
     Reset feature was removed for users due to it's complexity.
     To get to the default state user can manually delete credentials and remove password under Settings.
     To restore this feature, use git history and add a cell to SettingsViewController in the main storyboard.
    */
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stboard = UIStoryboard(name: "Main", bundle: nil)
        let webVC = stboard.instantiateViewController(withIdentifier: "WebViewController") as! WebViewController
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            if !self.viewModel.keyPluggedIn {
                self.viewModel.getKeyVersion()
            } else {
                // Workaround for modal segue bug: segue is very slow and takes up to 6sec to appear.
                // Here is a link: https://stackoverflow.com/questions/28509252/performseguewithidentifier-very-slow-when-segue-is-modal
                DispatchQueue.main.async { [weak self] in
                    self?.performSegue(withIdentifier: "ShowDeviceInfo", sender: self)
                }
            }
        case (0, 2):
            self.viewModel.getConfiguration()
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
            if let description = viewModel.keyDescription {
                title += ", key \(description.firmwareRevision)"
            }
            
            title = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "[iOSAuthenticator]"
            webVC.url = URL(string: "http://support.yubico.com/support/tickets/new?setField-helpdesk_ticket_subject=\(title)")
            self.navigationController?.pushViewController(webVC, animated: true)
            
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
