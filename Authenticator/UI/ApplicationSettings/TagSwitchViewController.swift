//
//  NfcTagSwitchViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/27/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

class TagSwitchViewController: BaseOATHVIewController {

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var tagSwitch: UISwitch!
    
    @IBAction func tagSwitched(_ sender: UISwitch) {
        self.isTagEnabled = sender.isOn
    }
    
    @IBAction func cancel(_ sender: Any) {
         dismiss(animated: true, completion: nil)
     }
     
     @IBAction func save(_ sender: Any) {
        self.performSegue(withIdentifier: .unwindToSettingsViewController, sender: sender)
     }
    
    var keyConfig: YKFMGMTInterfaceConfiguration? = nil
    var isTagEnabled = false
    let keyPluggedIn = YubiKitManager.shared.accessorySession.sessionState == .open
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let config = self.keyConfig {
            if keyPluggedIn {
                self.isTagEnabled = config.isEnabled(.OTP, overTransport: .USB)
            } else {
                self.isTagEnabled = config.isEnabled(.OTP, overTransport: .NFC)
            }
        }
        self.tagSwitch.setOn(isTagEnabled, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let button = sender as? UIBarButtonItem, button == saveButton {
            if keyPluggedIn {
                self.keyConfig?.setEnabled(self.isTagEnabled, application: .OTP, overTransport: .USB)
            } else {
                self.keyConfig?.setEnabled(self.isTagEnabled, application: .OTP, overTransport: .NFC)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if keyPluggedIn {
            cell.textLabel?.text = "Touch Tag"
        } else {
            cell.textLabel?.text = "NFC Tag"
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if keyPluggedIn {
            return "This setting turns on/off the Ybekey touch tag."
        }
        return "This setting turns on/off the Ybekey NFC website notigicsation tag."
    }
}
