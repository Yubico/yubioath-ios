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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LabelCell")
     
        keySessionObserver = KeySessionObserver(delegate: self)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
            case 0:
                return 1
            case 1:
                return keyPluggedIn ? 2 : 0
            case 2:
                return 1
            default:
                return 0
        }
        // #warning Incomplete implementation, return the number of rows
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 {
            if (indexPath.row == 0) {
                self.present(UIAlertController.setPassword(title: "Set password", message: "", inputHandler: {  (password) -> Void in
                    let viewModel = YubikitManagerModel()
                    viewModel.setCode(password: password)
                }), animated: true)
            } else if (indexPath.row == 1) {
                let viewModel = YubikitManagerModel()
                viewModel.reset()
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if (section == 1  && !keyPluggedIn) {
            return CGFloat.leastNonzeroMagnitude
        } else {
            return UITableView.automaticDimension;
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
            case 0:
                return "Device"
            case 1:
                return keyPluggedIn ? "OATH" : nil
            case 2:
                return "About"
            default:
                return nil
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LabelCell", for: indexPath)
            let description = YubiKitManager.shared.keySession.keyDescription;
            cell.textLabel?.text = keyPluggedIn ?
                "\(description?.name ?? "YubiKey") (\(description?.serialNumber ?? "000000"))" : "No device found"
            return cell
        }
        return super.tableView(tableView, cellForRowAt: indexPath)
    }
    

    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

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
