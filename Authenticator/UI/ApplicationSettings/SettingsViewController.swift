//
//  SettingsViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/7/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class SettingsViewController: BaseOATHVIewController {
    private var keyPluggedIn = YubiKitManager.shared.keySession.sessionState == .open;
    private var appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    private var systemVersion = UIDevice().systemVersion
    private var keySessionObserver: KeySessionObserver!
    
    override func viewWillAppear(_ animated: Bool) {
        keySessionObserver = KeySessionObserver(delegate: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        keySessionObserver.observeSessionState = false
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = super.tableView(tableView, heightForRowAt: indexPath)
        
        // hide OATH specific commands: Set password and reset
        if (indexPath.section == 0 && indexPath.row != 0) {
            return keyPluggedIn ? 80.0 : 0.0
        }
        
        return height
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if indexPath.section == 0 && indexPath.row == 0 {
            if let description = YubiKitManager.shared.keySession.keyDescription {
                cell.textLabel?.text = "\(description.name) (\(description.firmwareRevision))"
                cell.detailTextLabel?.text = "Serial number: \(description.serialNumber)"
            } else {
                cell.textLabel?.text = keyPluggedIn ? "YubiKey" : "No device found"
                cell.detailTextLabel?.text = ""
            }

        } else if (indexPath.section == 2 && indexPath.row == 0) {
            cell.textLabel?.text = "Yubico Authenticator \(appVersion)"
        }
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 && indexPath.row == 2 {
            showResetWarning { [weak self]  () -> Void in
                self?.viewModel.reset()
            }
        } else if indexPath.section == 1 {
            switch indexPath.row {
            case 0:
                if let url = URL(string: "https://www.yubico.com/support/terms-conditions/yubico-license-agreement/"){
                    UIApplication.shared.open(url)
                }
            case 1:
                if let url = URL(string: "https://www.yubico.com/support/terms-conditions/privacy-notice/"){
                    UIApplication.shared.open(url)
                }
            default:
                var title = "[iOS Authenticator] \(appVersion), iOS\(systemVersion)"
                if let description = YubiKitManager.shared.keySession.keyDescription {
                    title += ", key \(description.firmwareRevision)"
                }
                    
                title = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "[iOSAuthenticator]"
                let urlPath = "http://support.yubico.com/support/tickets/new?setField-helpdesk_ticket_subject=\(title)"
                if let url = URL(string: urlPath) {
                    UIApplication.shared.open(url)
                }
            }            
        }
    }
    
    // MARK: - private helper methods
    private func showResetWarning(okHandler: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: "Reset OATH application?", message: "This will delete all credentials and restore factory defaults.", preferredStyle: .alert)
        
        let reset = UIAlertAction(title: "Reset", style: .destructive, handler: { (action) -> Void in
            okHandler?()
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in }
        alertController.addAction(reset)
        alertController.addAction(cancel)
        
        self.present(alertController, animated: false)
    }

}

//
// MARK: - Key Session Observer
//
extension  SettingsViewController: KeySessionObserverDelegate {
    
    func keySessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFKeySessionState) {
        self.keyPluggedIn = YubiKitManager.shared.keySession.sessionState == .open;
        self.tableView.reloadData()
    }
}
