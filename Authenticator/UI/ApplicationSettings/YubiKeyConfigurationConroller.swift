//
//  YubiKeyConfigurationConroller.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/27/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit
import FirebaseAnalytics
/* This class is for showing YubiKey MGMT configuration over OTP whether it's on or off.
 Users can customize the configuration by switching tagSwitch and saving the change.
 For YubiKey NFC it is showing website NFC tag notification on YubiKey tap against the device.
 For YubiKey 5Ci it is printing key string in text fields on YubiKey touch.
 */
class YubiKeyConfigurationConroller: BaseOATHVIewController {

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
    
    var keyConfiguration: YKFMGMTInterfaceConfiguration? = nil
    var isTagEnabled = false
    let keyPluggedIn = YubiKitManager.shared.accessorySession.sessionState == .open
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Analytics.setScreenName("KeyConfiguration", screenClass: "YubiKeyConfigurationConroller")
        if let keyConfig = self.keyConfiguration {
            if keyPluggedIn {
                self.isTagEnabled = keyConfig.isEnabled(.OTP, overTransport: .USB)
            } else {
                self.isTagEnabled = keyConfig.isEnabled(.OTP, overTransport: .NFC)
            }
        }
        self.tagSwitch.setOn(isTagEnabled, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let button = sender as? UIBarButtonItem, button == saveButton {
            if keyPluggedIn {
                self.keyConfiguration?.setEnabled(self.isTagEnabled, application: .OTP, overTransport: .USB)
            } else {
                self.keyConfiguration?.setEnabled(self.isTagEnabled, application: .OTP, overTransport: .NFC)
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if keyPluggedIn {
            cell.textLabel?.text = NSLocalizedString("Touch Tag", comment: "Title for tag setting switch on YubiKey 5Ci, turn on/off printing key string on touch.")
        } else {
            cell.textLabel?.text = NSLocalizedString("NFC Tag", comment: "Title for tag setting switch on YubiKey NFC, turn on/off website NFC tag notification on every key tap.")
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if keyPluggedIn {
            return NSLocalizedString("This setting turns on/off printing key string in text fields when you touch the YubiKey.", comment: "Description for tag setting switch on Yubikey 5Ci.")
        }
        return NSLocalizedString("This setting turns on/off website NFC tag notification when you tap the YubiKey.", comment: "Description for tag setting switch on Yubikey NFC.")
    }
}
