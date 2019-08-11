//
//  MainViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class MainViewController: UITableViewController {

    let viewModel = YubikitManagerModel()
    private var credentialsSearchController: UISearchController!
    private var keySessionObserver: KeySessionObserver!

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        
        keySessionObserver = KeySessionObserver(delegate: self)
        setupCredentialsSearchController()
        
        if (!YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
            // TODO: notify user that it's not supported on this device
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshUIOnKeyStateUpdate()
    }
    
    // MARK: - UI Setup
    
    private func setupCredentialsSearchController() {
        credentialsSearchController = UISearchController(searchResultsController: nil)
        credentialsSearchController.searchResultsUpdater = self
        credentialsSearchController.obscuresBackgroundDuringPresentation = false
        credentialsSearchController.searchBar.placeholder = "Search Credentials"
        definesPresentationContext = true
    }
    
    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        if (viewModel.credentials.count > 0) {
            self.tableView.backgroundView = nil
            self.tableView.separatorStyle = .singleLine
            return 1
        } else {
            // Display a message when the table is empty
            let messageLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
            messageLabel.textAlignment = NSTextAlignment.center
            messageLabel.numberOfLines = 5
            
            if YubiKitManager.shared.keySession.sessionState == .closed {
                messageLabel.text = "Insert your YubiKey"
            } else {
                messageLabel.text = "No credentials.\nAdd credential to this YubiKey in order to be able to generate security codes from it."
            }
            messageLabel.textColor = UIColor.black;
            messageLabel.sizeToFit()
            
            self.tableView.backgroundView = messageLabel;
            self.tableView.separatorStyle = .none
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.credentials.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CredentialCell", for: indexPath) as! CredentialTableViewCell
        let credential = viewModel.credentials[indexPath.row]
        cell.updateView(credential: credential)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let credential = viewModel.credentials[indexPath.row]
            if (credential.code.isEmpty) {
                viewModel.calculate(credential: credential)
            } else {
                // copy to clipbboard
                UIPasteboard.general.string = credential.code
                // notify user
            }
        }
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            viewModel.deleteCredential(index: indexPath.row)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    
    @IBAction func unwindToMainViewController(segue: UIStoryboardSegue) {
        if let sourceViewController = segue.source as? AddCredentialController, let credential = sourceViewController.credential {
            // Add a new credentail to table.
            viewModel.addCredential(credential: credential)
        }
    }
    
    private func refreshCredentials() {
        if (YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
            let sessionState = YubiKitManager.shared.keySession.sessionState
            print("Key session state: \(String(describing: sessionState.rawValue))")
            
            if (sessionState == YKFKeySessionState.open) {
                viewModel.calculateAll()
            } else {
                // if YubiKey is unplugged do not show any OTP codes
                viewModel.cleanUp()
            }
        } else {
            // TODO: remove before release
            viewModel.emulateSomeRecords()
        }
    }
    
    private func refreshUIOnKeyStateUpdate() {
        refreshCredentials()
        
        if YubiKitManager.shared.keySession.sessionState == .closed {
            navigationItem.searchController = nil
            navigationItem.hidesSearchBarWhenScrolling = true
            navigationItem.rightBarButtonItems?[1].isEnabled = false
        } else {
            navigationItem.searchController = credentialsSearchController
            navigationItem.hidesSearchBarWhenScrolling = false
            navigationItem.rightBarButtonItems?[1].isEnabled = true
            
        }
        view.setNeedsLayout()
    }
    
}

// MARK: - CredentialViewModelDelegate
extension MainViewController:  CredentialViewModelDelegate {
    func onUpdated() {
        self.tableView.reloadData()
    }
    
    func onError(error: Error) {
        // TODO: add pull to refresh feaute so that in case of some error user can retry to read all (no need to unplug and plug)
        print("\(error)")
        if let oathError = error as? YKFKeyOATHError {
            // TODO: add queue of requests and in case of authentication error be able to retry what was requested
            if (oathError.code == YKFKeyOATHErrorCode.authenticationRequired.rawValue) {
                self.present(UIAlertController.setPassword(title: "Unlock YubiKey", message: "To prevent anauthorized access YubiKey is protected with a password", inputHandler: {  (password) -> Void in
                    self.viewModel.validate(password: password)
                }), animated: true)
            } else {
                self.present(UIAlertController.errorDialog(title: "Error occured", message: error.localizedDescription), animated: true)
            }
        } else {
            // TODO: add localizedDescription to KeySessionError
            self.present(UIAlertController.errorDialog(title: "Error occured", message: error.localizedDescription), animated: true)
        }
    }
}

//
// MARK: - Key Session Observer
//
extension  MainViewController: KeySessionObserverDelegate {
    
    func keySessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFKeySessionState) {
        refreshUIOnKeyStateUpdate()
    }
}

//
// MARK: - Search Results Extension
//

extension MainViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let filter = searchController.searchBar.text
        viewModel.applyFilter(filter: filter)
    }
}
