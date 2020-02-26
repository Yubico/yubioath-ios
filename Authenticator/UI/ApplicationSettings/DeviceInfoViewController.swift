//
//  DeviceInfoViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/21/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

enum DeviceInfoTitles: Int, CaseIterable {
    case model = 0
    case serial
    case firmware
    
    var title: String {
        switch self {
        case .model:
            return "Model"
        case .serial:
            return "Serial number"
        case .firmware:
            return "Firmware version"
        }
    }
}

class DeviceInfoViewController: BaseOATHVIewController {

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    var keyDescription: YKFAccessoryDescription? = nil
    var keyVersion: YKFKeyVersion? = nil
    var keyIdentifier: String? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return DeviceInfoTitles.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceInfoTableViewCell", for: indexPath) as! DeviceInfoTableViewCell
        cell.titleLabel.text = DeviceInfoTitles.allCases[indexPath.row].title
        
        switch indexPath.row {
        case 0:
            if let description = keyDescription {
                cell.infoLabel?.text = description.name
            } else {
                cell.infoLabel?.text = "YubiKey NFC"
            }
        case 1:
            if let description = keyDescription {
                cell.infoLabel?.text = description.serialNumber
            } else {
                cell.infoLabel?.text = keyIdentifier
            }
        case 2:
            if let description = keyDescription {
                cell.infoLabel?.text = description.firmwareRevision
            } else {
                if let firmwareVersion = keyVersion {
                    cell.infoLabel?.text = "\(firmwareVersion.major).\(firmwareVersion.minor).\(firmwareVersion.micro)"
                }
            }
        default:
            break;
        }
        
        return cell
    }
}
