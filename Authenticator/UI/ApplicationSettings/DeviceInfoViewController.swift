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
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if keyDescription == nil && indexPath.row == 1 {
            return 0
        }
        return 44
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
            if let firmwareVersion = keyVersion {
                switch indexPath.row {
                case 0:
                    if Int(firmwareVersion.major) < 4 {
                        cell.detailTextLabel?.text = "YubiKey NEO"
                    } else if Int(firmwareVersion.major) == 5 {
                        cell.detailTextLabel?.text = "YubiKey 5 NFC"
                    } else {
                        cell.detailTextLabel?.text = "YubiKey NFC"
                    }
                case 2:
                    if Int(firmwareVersion.major) < 4 {
                        cell.textLabel?.text = "OATH version"
                    } else {
                        cell.textLabel?.text = "Firmware version"
                    }
                    cell.detailTextLabel?.text = "\(firmwareVersion.major).\(firmwareVersion.minor).\(firmwareVersion.micro)"
                    
                default:
                    break
                }
            }
        }

        return cell
    }
}
