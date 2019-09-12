//
//  SettingsViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/7/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
    // TODO: observe state changes and update keyPluggedIn property
    private var keyPluggedIn = YubiKitManager.shared.keySession.sessionState == .open;
    private var keySessionObserver: KeySessionObserver!

    private let viewModel = YubikitManagerModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // register cell identifiers
        viewModel.delegate = self
     
    }
    
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
            let description = YubiKitManager.shared.keySession.keyDescription;
            cell.textLabel?.text = keyPluggedIn ?
                "\(description?.name ?? "YubiKey") (\(description?.serialNumber ?? "000000"))" : "No device found"
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
// MARK: - CredentialViewModelDelegate
//
extension SettingsViewController:  CredentialViewModelDelegate {
    func onError(operation: Operation, error: Error) {
        // If error happened during reset operation
        self.showAlertDialog(title: "Error occured", message: error.localizedDescription)
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
