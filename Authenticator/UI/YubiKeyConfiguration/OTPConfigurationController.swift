//
//  YubiKeyConfigurationConroller.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/27/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

/* This class is for showing YubiKey MGMT configuration over OTP whether it's on or off.
 Users can customize the configuration by switching tagSwitch and saving the change.
 For YubiKey NFC it is showing website NFC tag notification on YubiKey tap against the device.
 For YubiKey 5Ci it is printing key string in text fields on YubiKey touch.
 */
class OTPConfigurationController: UITableViewController {
    
    public var viewModel = ManagementViewModel()
    var configuration: ManagementViewModel.OTPConfiguration? = nil

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var tagTypeLabel: UILabel!
    @IBOutlet weak var tagSwitch: UISwitch!
    
    func dismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func changeSetting(_ sender: UISwitch) {
        viewModel.setOTPEnabled(enabled: sender.isOn) { error in
            DispatchQueue.main.async {
                guard error == nil else {
                    let alert = UIAlertController(title: "Error writing configuration", message: error?.localizedDescription, preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .default) { _ in
                        self.dismiss()
                    }
                    alert.addAction(action)
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                    return
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.isOTPEnabled { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let configuration):
                    self.configuration = configuration
                    self.tagSwitch.isOn = configuration.isEnabled
                    self.tagSwitch.isEnabled = configuration.isSupported && !configuration.isConfigurationLocked
                    self.tagTypeLabel.text = configuration.transport == .NFC ? "NFC tag" : "Touch tag"
                    if self.tagSwitch.isEnabled {
                        if configuration.transport == .USB {
                            self.descriptionLabel.text = "This setting turns on/off printing key string in text fields when you touch the YubiKey."
                        }
                        if configuration.transport == .NFC {
                            self.descriptionLabel.text = "This setting turns on/off printing key string in text fields when you touch the YubiKey."
                        }
                    } else {
                        self.descriptionLabel.text = "This setting is not supported on your YubiKey."
                    }
                    self.descriptionLabel.sizeToFit()
                case .failure(let error):
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .default) { _ in
                        self.dismiss()
                    }
                    alert.addAction(action)
                    self.dismiss()
                }
            }
        }
        
        viewModel.didDisconnect { [weak self] connection, error in
            if error != nil || (connection as? YKFAccessoryConnection) != nil {
                let alert = UIAlertController(title: "YubiKey disconnected", message: error?.localizedDescription, preferredStyle: .alert)
                let action = UIAlertAction(title: "Ok", style: .default) { _ in
                    self?.dismiss()
                }
                alert.addAction(action)
                DispatchQueue.main.async {
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    deinit {
        print("deinit OTPConfigurationController")
    }
}
