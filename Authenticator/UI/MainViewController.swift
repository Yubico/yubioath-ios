//
//  MainViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class MainViewController: UITableViewController, CredentialViewModelDelegate {

    let viewModel = YubikitManagerModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.delegate = self
        if (YubiKitDeviceCapabilities.supportsLightningKey) {
            YubiKitManager.shared.keySession.startSession()
            observeSessionStateUpdates = true
        } else {
            // emulation
            let credentialResult = YKFOATHCredential()
            credentialResult.account = "account1"
            credentialResult.issuer = "issuer1"
            credentialResult.type = YKFOATHCredentialType.TOTP;
            viewModel.credentials.insert(Credential(
                fromYKFOATHCredential: credentialResult,
                otp: "111 222",
                valid: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(30))))

            credentialResult.account = "account2"
            credentialResult.issuer = "issuer2"
            viewModel.credentials.insert(Credential(
                fromYKFOATHCredential: credentialResult,
                otp: "",
                valid: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(30))))

            credentialResult.account = "account3"
            credentialResult.type = YKFOATHCredentialType.HOTP;
            viewModel.credentials.insert(Credential(
                fromYKFOATHCredential: credentialResult,
                otp: "333 444",
                valid: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(30))))

        }
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
         self.navigationItem.rightBarButtonItem = self.editButtonItem
    }
    
    // MARK: - CredentialViewModelDelegate
    func onUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.credentials.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CredentialCell", for: indexPath) as! CredentialTableViewCell
        let credential = viewModel.credentialsArray[indexPath.row]
        cell.code.text = credential.code
        cell.issuer.text = credential.issuer
        cell.name.text = credential.account
        
        if (credential.type == .TOTP && !credential.code.isEmpty) {
            cell.progress.setProgress(to: 100, duration: Double(credential.period) ,step: 1.0) {
                self.viewModel.calculate(oathService: YubiKitManager.shared.keySession.oathService, credential: credential)
            }
        } else {    
            cell.progress.isHidden = true
        }
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
//            tableView.deleteRows(at: [indexPath], with: .fade)
            viewModel.deleteCredential(oathService: YubiKitManager.shared.keySession.oathService,
                                       credential: viewModel.credentialsArray[indexPath.row])
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
            viewModel.addCredential(oathService: YubiKitManager.shared.keySession.oathService, credential: credential)
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
                self?.keySessionStateDidChange()
            }
        default:
            fatalError()
        }
    }
    
    func keySessionStateDidChange() {
        let sessionState = YubiKitManager.shared.keySession.sessionState
        print("Key session state: \(String(describing: sessionState.rawValue))")
        if (sessionState == YKFKeySessionState.open) {
            guard let oathService = YubiKitManager.shared.keySession.oathService else {
                return
            }
            viewModel.calculateAll(oathService: oathService as! YKFKeyOATHService)
        } else {
            // if YubiKey is unplugged do not how any OTP codes
            viewModel.credentials.removeAll()
            onUpdated()
        }
    }
}
