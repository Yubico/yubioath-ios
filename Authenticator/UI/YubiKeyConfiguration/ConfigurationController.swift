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
import SwiftUI

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
                let alert = UIAlertController(title: String(localized: "Smart card extension is only available on iOS 14.5 and forward.", comment: "PIV extension version error"), message: nil, completion: {})
                self.present(alert, animated: true, completion: nil)
            default: break
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !YubiKitDeviceCapabilities.supportsISO7816NFCTags && indexPath.section == 1 && indexPath.row == 2 {
            return 0
        } else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
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
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            let refreshControl = UIRefreshControl()
            refreshControl.backgroundColor = .clear
            refreshControl.addTarget(self, action:  #selector(startNFC), for: .valueChanged)
            self.refreshControl = refreshControl
        }
        
        insertYubiKeyLabel.text = YubiKitDeviceCapabilities.supportsISO7816NFCTags ? String(localized: "Insert YubiKey or pull down to activate NFC") : String(localized: "Insert YubiKey")
        
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
                    let alert = UIAlertController(title: String(localized: "Error reading YubiKey"), message: error.localizedDescription) { }
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

extension ConfigurationController {
    @IBSegueAction func showOATHResetView(_ coder: NSCoder) -> UIViewController? {
        let controller = UIHostingController(coder: coder, rootView: OATHResetView())
        controller?.title = "Reset OATH"
        return controller
    }
    
    @IBSegueAction func showOATHPasswordView(_ coder: NSCoder) -> UIViewController? {
        let controller = UIHostingController(coder: coder, rootView: OATHPasswordView())
        controller?.title = "OATH password"
        return controller
    }
    
    @IBSegueAction func showOATHSavedPasswordsView(_ coder: NSCoder) -> UIViewController? {
        let controller = UIHostingController(coder: coder, rootView: OATHSavedPasswordsView())
        controller?.title = "OATH saved password"
        return controller
    }
    
    @IBSegueAction func showFIDOPINView(_ coder: NSCoder) -> UIViewController? {
        let controller = UIHostingController(coder: coder, rootView: FIDOPINView())
        controller?.title = "FIDO PIN"
        return controller
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
