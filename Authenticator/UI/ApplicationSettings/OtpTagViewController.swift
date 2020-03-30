//
//  OtpTagViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 3/30/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

import UIKit

class OtpTagViewController: BaseOATHVIewController {

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    var token: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.textLabel?.text = self.token ?? ""
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let token = self.token {
            self.viewModel.copyToClipboard(string: token)
        }
    }
}

