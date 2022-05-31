/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import UIKit

class ConfigurationController: UITableViewController {
    
    @IBOutlet var smartCardEnabledLabel: UILabel!
    
    @IBOutlet weak var serialNumberLabel: UILabel!
    @IBOutlet weak var firmwareVersionLabel: UILabel!
    @IBOutlet weak var deviceTypeLabel: UILabel!
    @IBOutlet weak var insertYubiKeyLabel: UILabel!
    
    @IBOutlet weak var keyPlaceholderImage: UIImageView!
    @IBOutlet weak var keyImage: UIImageView!
    
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
        
        insertYubiKeyLabel.text = YubiKitDeviceCapabilities.supportsISO7816NFCTags ? "Insert YubiKey or pull down to activate NFC" : "Insert YubiKey"
        
        self.refreshControl = refreshControl
        infoViewModel.deviceInfo { [weak self] result in
            DispatchQueue.main.async {
                guard let result = result else { self?.reset(); return }
                self?.insertYubiKeyLabel.isHidden = false
                switch result {
                case .success(let info):
                    self?.keyPlaceholderImage.isHidden = true
                    self?.keyImage.image = info.deviceImage
                    self?.keyImage.isHidden = false
                    self?.insertYubiKeyLabel.isHidden = true
                    self?.serialNumberLabel.text = "\(info.serialNumber)"
                    self?.deviceTypeLabel.text = info.deviceName
                    self?.firmwareVersionLabel.text = info.version.description
                case .failure(let error):
                    self?.reset()
                    let alert = UIAlertController(title: "Error reading YubiKey", message: error.localizedDescription) { }
                    self?.present(alert, animated: true, completion: nil)
                }
            }
        }
    }
    
    func reset() {
        self.keyPlaceholderImage.isHidden = false
        self.keyImage.isHidden = true
        self.insertYubiKeyLabel.isHidden = false
        self.serialNumberLabel.text = "N/A"
        self.deviceTypeLabel.text = "N/A"
        self.firmwareVersionLabel.text = "N/A"
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
    
    var deviceImage: UIImage? {
        switch formFactor {
        case .usbaKeychain:
            return UIImage(named: "yk5nfc")
        case .usbcKeychain:
            return UIImage(named: "yk5cnfc")
        case .usbcLightning:
            return UIImage(named: "yk5ci")
        default:
            return nil
        }
    }
}
