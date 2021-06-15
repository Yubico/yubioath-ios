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
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        switch (indexPath.section, indexPath.row) {
        case (2, 1):
            cell.textLabel?.text = "Yubico Authenticator \(UIApplication.appVersion) (build \(UIApplication.appBuildNumber))"
        default:
            break
        }
        return cell
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }
    
    /*
     Reset feature was removed for users due to it's complexity.
     To get to the default state user can manually delete credentials and remove password under Settings.
     To restore this feature, use git history and add a cell to SettingsViewController in the main storyboard.
    */
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
            
        case (2, 0):
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "ShowWhatsNew", sender: self)
            }
        default:
            break
        }
    }
}
