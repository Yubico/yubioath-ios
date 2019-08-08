//
//  MainViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class MainViewController: UITableViewController, CredentialViewModelDelegate, CredentialExpirationDelegate {

    let viewModel = YubikitManagerModel()
    private var timerObservation: NSKeyValueObservation?
    @objc dynamic private var globalTimer = GlobalTimer.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        if (YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
            observeSessionStateUpdates = true
        } else {
            // TODO: notify user that it's not supported on this device
            // emulation
            let credentialResult = YKFOATHCredential()
            credentialResult.account = "account1"
            credentialResult.issuer = "issuer1"
            credentialResult.type = YKFOATHCredentialType.TOTP;
            let credential = Credential(fromYKFOATHCredential: credentialResult)
            credential.code = "111222"
            credential.setValidity(validity: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(30)))
            credential.setupTimerObservation()
            viewModel.credentials.append(credential)
            let credential2 = credential.copy() as! Credential
            credential2.code = "444555"
            credential2.setValidity(validity: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(20)))
            credential2.setupTimerObservation()
            viewModel.credentials.append(credential2)
            let credential3 = credential.copy() as! Credential
            credential3.code = "999888"
            credential3.setValidity(validity: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(40)))
            credential3.setupTimerObservation()
            viewModel.credentials.append(credential3)
        }
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshUI()
    }
    
    // MARK: - CredentialViewModelDelegate
    func onUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    func onError(error: Error) {
        DispatchQueue.main.async { [weak self] in
            print("\(error)")
            if let oathError = error as? YKFKeyOATHError {
                if (oathError.code == YKFKeyOATHErrorCode.authenticationRequired.rawValue) {
                    self?.present(UIAlertController.setPassword(title: "Unlock YubiKey", message: "To prevent anauthorized access YubiKey is protected with a password", inputHandler: {  (password) -> Void in
                        self?.viewModel.validate(password: password)
                    }), animated: true)
                } else {
                    self?.present(UIAlertController.errorDialog(title: "Error occured", message: error.localizedDescription), animated: true)
                }
            } else {
                self?.present(UIAlertController.errorDialog(title: "Error occured", message: error.localizedDescription), animated: true)
            }
        }
    }

    // MARK: - CredentialExpirationDelegate
    func calculateResultDidExpire(_ credential: Credential) {
        viewModel.calculate(credential: credential)
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
        credential.delegate = self
        cell.updateView(credential: credential)
        return cell
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
    

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
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
    
    
    // MARK: - State Observation
    
    private static var observationContext = 0
    private var isObservingSessionStateUpdates = false
    
    var observeSessionStateUpdates: Bool {
        get {
            return isObservingSessionStateUpdates
        }
        set {
            guard newValue != isObservingSessionStateUpdates else {
                return
            }
            isObservingSessionStateUpdates = newValue
            
            let keySession = YubiKitManager.shared.keySession as AnyObject
            let keyPath = #keyPath(YKFKeySession.sessionState)
            
            if isObservingSessionStateUpdates {
                keySession.addObserver(self, forKeyPath: keyPath, options: [], context: &MainViewController.observationContext)
            } else {
                keySession.removeObserver(self, forKeyPath: keyPath)
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard context == &MainViewController.observationContext else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        switch keyPath {
        case #keyPath(YKFKeySession.sessionState):
            DispatchQueue.main.async { [weak self] in
                self?.refreshUI()
            }
        default:
            fatalError()
        }
    }
    
    
    private func refreshUI() {
        let sessionState = YubiKitManager.shared.keySession.sessionState
        print("Key session state: \(String(describing: sessionState.rawValue))")
        
        if (sessionState == YKFKeySessionState.open) {
            viewModel.calculateAll()
        } else {
            // if YubiKey is unplugged do not show any OTP codes
            viewModel.cleanUp()
        }
    }
}
