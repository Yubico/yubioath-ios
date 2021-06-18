//
//  YubiKeyConfigurationController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-28.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import UIKit

class ConfigurationController: UITableViewController {
    
    @IBOutlet var smartCardEnabledLabel: UILabel!
    
    @IBOutlet weak var serialNumberLabel: UILabel!
    @IBOutlet weak var firmwareVersionLabel: UILabel!
    @IBOutlet weak var deviceTypeLabel: UILabel!
    @IBOutlet weak var insertYubiKeyLabel: UILabel!
    @IBOutlet weak var deviceInfoContainerView: UIView!
    
    let infoViewModel = YubiKeyInformationViewModel()
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if #available(iOS 14.5, *) { } else {
            switch (indexPath.section, indexPath.row) {
            case (3, 0):
                let alert = UIAlertController(title: "Smart card extension is only available on iOS 14.5 and forward.", message: nil, completion: {})
                self.present(alert, animated: true, completion: nil)
            default: break
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if #available(iOS 14.5, *) {
            return true
        } else {
            return identifier != "showSmartCardCertificates"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let refreshControl = UIRefreshControl()
        refreshControl.backgroundColor = .clear
        refreshControl.addTarget(self, action:  #selector(startNFC), for: .valueChanged)
        self.refreshControl = refreshControl
        infoViewModel.deviceInfo { [weak self] result in
            DispatchQueue.main.async {
                self?.deviceInfoContainerView.isHidden = true
                self?.insertYubiKeyLabel.isHidden = false
                guard let result = result else { return }
                switch result {
                case .success(let info):
                    self?.deviceInfoContainerView.isHidden = false
                    self?.insertYubiKeyLabel.isHidden = true
                    self?.serialNumberLabel.text = "\(info.serialNumber)"
                    self?.deviceTypeLabel.text = info.deviceName
                    self?.firmwareVersionLabel.text = info.version.description
                case .failure(let error):
                    let alert = UIAlertController(title: "Error reading YubiKey", message: error.localizedDescription) { }
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    @objc func startNFC() {
        YubiKitManager.shared.startNFCConnection()
        refreshControl?.endRefreshing()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 14.5, *) {
            smartCardEnabledLabel.isHidden = TokenCertificateStorage().listTokenCertificates().count == 0
        }
    }
    
    deinit {
        print("Deinit ConfigurationController")
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
