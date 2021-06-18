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
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        let webViewController = storyBoard.instantiateViewController(withIdentifier: "WebViewController") as! WebViewController
        
        switch (indexPath.section, indexPath.row) {
        case (1, 0):
            webViewController.url = URL(string: "https://www.yubico.com/support/terms-conditions/yubico-license-agreement/")
            self.navigationController?.pushViewController(webViewController, animated: true)
        case (1, 1):
            webViewController.url = URL(string: "https://www.yubico.com/support/terms-conditions/privacy-notice/")
            self.navigationController?.pushViewController(webViewController, animated: true)
        case (1, 2):
            var title = "[iOS Authenticator] \(UIApplication.appVersion), iOS\(UIDevice().systemVersion)"
            //            if let description = viewModel.keyDescription {
            //                title += ", key \(description.firmwareRevision)"
            //            }
            
            title = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "[iOSAuthenticator]"
            webViewController.url = URL(string: "https://support.yubico.com/support/tickets/new?setField-helpdesk_ticket_subject=\(title)")
            self.navigationController?.pushViewController(webViewController, animated: true)
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
