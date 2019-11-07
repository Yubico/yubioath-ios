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
    
    private var appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    private var systemVersion = UIDevice().systemVersion
    private var keySessionObserver: KeySessionObserver!
    
    override func viewWillAppear(_ animated: Bool) {
        keySessionObserver = KeySessionObserver(accessoryDelegate: self, nfcDlegate: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        keySessionObserver.observeSessionState = false
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = super.tableView(tableView, heightForRowAt: indexPath)
        
        // hide OATH specific commands: Set password and reset
        if indexPath.section == 0 && indexPath.row != 0 {
            return allowKeyOperations || viewModel.keyPluggedIn ? 80.0 : 0.0
        }
        
        return height
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch (indexPath.section, indexPath.row) {
        case (0,0):
            if let description = viewModel.keyDescription {
                cell.textLabel?.text = "\(description.name) (\(description.firmwareRevision))"
                cell.detailTextLabel?.text = "Serial number: \(description.serialNumber)"
            } else {
                cell.textLabel?.text = viewModel.keyPluggedIn ? "YubiKey" : "No device found"
                cell.detailTextLabel?.text = ""
            }
        case (3,0):
            cell.textLabel?.text = "Yubico Authenticator \(appVersion)"
        default:
            break;
        }
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 2):
            self.showWarning(title: "Reset OATH application?", message: "This will delete all accounts and restore factory defaults of your YubiKey.", okButtonTitle: "Reset") { [weak self]  () -> Void in
                self?.viewModel.reset()
            }
        case (1, 0):
            self.showWarning(title: "Remove stored passwords?", message: "If you have set password on your YubiKey you will be prompted for it on next usage.", okButtonTitle: "Forget") { [weak self]  () -> Void in
                self?.removeStoredPasswords()
            }
        case (2, 0):
            if let url = URL(string: "https://www.yubico.com/support/terms-conditions/yubico-license-agreement/"){
                UIApplication.shared.open(url)
            }
        case (2, 1):
            if let url = URL(string: "https://www.yubico.com/support/terms-conditions/privacy-notice/"){
                UIApplication.shared.open(url)
            }
        case (2, 2):
            var title = "[iOS Authenticator] \(appVersion), iOS\(systemVersion)"
            if let description = viewModel.keyDescription {
                title += ", key \(description.firmwareRevision)"
            }
                
            title = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "[iOSAuthenticator]"
            let urlPath = "http://support.yubico.com/support/tickets/new?setField-helpdesk_ticket_subject=\(title)"
            if let url = URL(string: urlPath) {
                UIApplication.shared.open(url)
            }
        default:
            break;
        }
    }
    
    // MARK: - private helper methods  
    private func removeStoredPasswords() {
        passwordPreferences.resetPasswordPreference()
        do {
          try secureStore.removeAllValues()
            self.showAlertDialog(title: "Success", message: "Saved passwords has been erased from the phone") { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            }
        } catch (let e) {
            self.showAlertDialog(title: "Error happend during cleaning up passwords", message: e.localizedDescription) { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
}

//
// MARK: - Key Session Observer
//
extension  SettingsViewController: AccessorySessionObserverDelegate {
    
    func accessorySessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFAccessorySessionState) {
        self.tableView.reloadData()
    }
}

extension  SettingsViewController: NfcSessionObserverDelegate {
    func nfcSessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFNFCISO7816SessionState) {
        
        print("NFC key session state: \(String(describing: state.rawValue))")
        if (state == .open) {
            viewModel.resume()
        }
    }
}
