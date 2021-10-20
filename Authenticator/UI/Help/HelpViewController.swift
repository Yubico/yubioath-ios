//
//  SettingsViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/7/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//


// SettingsViewController
//   - start accessory connection when view becomes active and adopt UI
//   -

import UIKit

class HelpViewController: UITableViewController {

    // MARK: - Table view data source
    
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        versionLabel.text = "\(UIApplication.appVersion) (build \(UIApplication.appBuildNumber))"
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 1):
            let whatsNewController = VersionHistoryViewController()
            whatsNewController.modalPresentationStyle = .popover
            self.present(whatsNewController, animated: true)
        case (0, 2):
            if let url = URL(string: "https://www.yubico.com/support/terms-conditions/yubico-license-agreement/") {
                UIApplication.shared.open(url)
            }
        case (0, 3):
            if let url = URL(string: "https://www.yubico.com/support/terms-conditions/privacy-notice/") {
                UIApplication.shared.open(url)
            }
        case (1, 0):
            if let url = URL(string: "https://support.yubico.com/") {
                UIApplication.shared.open(url)
            }
        case (1, 1):
            if let url = URL(string: "https://support.yubico.com/support/tickets/new") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
