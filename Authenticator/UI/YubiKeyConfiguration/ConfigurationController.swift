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
    
    override func viewWillAppear(_ animated: Bool) {
        if #available(iOS 14.5, *) {
            smartCardEnabledLabel.isHidden = TokenCertificateStorage().listTokenCertificates().count == 0
        }
    }
    
    deinit {
        print("Deinit ConfigurationController")
    }

}
