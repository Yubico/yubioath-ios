//
//  DeviceInfoViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/21/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

class DeviceInfoViewController: BaseOATHVIewController {
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    var keyDescription: YKFAccessoryDescription?
    var keyVersion: YKFKeyVersion?
    var keyIdentifier: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        if let description = keyDescription {
            switch indexPath.row {
            case 0: cell.detailTextLabel?.text = description.name
            case 1: cell.detailTextLabel?.text = description.serialNumber
            case 2: cell.detailTextLabel?.text = description.firmwareRevision
            default:
                break
            }
        } else {
            switch indexPath.row {
            case 0: cell.detailTextLabel?.text = "YubiKey NFC"
            case 1:
                cell.textLabel?.text = "Unique ID"
                if let keyId = self.keyIdentifier {
                    cell.detailTextLabel?.text = keyId
                }
            case 2:
                if let firmwareVersion = keyVersion {
                    cell.detailTextLabel?.text = "\(firmwareVersion.major).\(firmwareVersion.minor).\(firmwareVersion.micro)"
                }
            default:
                break
            }
        }

        return cell
    }
}