//
//  DeviceInfoViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/21/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

class YubiKeyInfoViewController: UITableViewController {
    
    public var viewModel: ManagementViewModel? = ManagementViewModel()
    
    @IBOutlet weak var serialNumberLabel: UILabel!
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var firmwareLabel: UILabel!
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        viewModel?.deviceInfo { result in
            switch result {
            case .success(let deviceInfo):
                DispatchQueue.main.async {
                    self.firmwareLabel.text = deviceInfo.version.description
                    self.modelLabel.text = deviceInfo.deviceName
                    self.serialNumberLabel.text = "\(deviceInfo.serialNumber)"
                }
            case .failure(let error):
                // TODO: handle error
                print(error)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.viewModel = nil
    }
    
    deinit {
        print("deinit DeviceInfoViewController")
    }
}

extension YKFManagementDeviceInfo {
    var deviceName: String {
        switch formFactor {
        case .usbaKeychain:
            let name: String
            if version.major == 5 { name = "5" } else
            if version.major < 4 { name = "NEO" }
            else { name = "" }
            return "YubiKey \(name) NFC"
        case .usbcKeychain:
            return "YubiKey 5C NFC"
        case .usbcLightning:
            return "YubiKey 5Ci"
        default:
            return "Unknown key"
        }
    }
}
