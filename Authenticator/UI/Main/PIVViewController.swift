//
//  PIVViewController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-18.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

class PIVViewController: UITableViewController {
    
    let viewModel = PIVViewModel()
    
    let keychainCerts = ["An important certificate", "Second Keychain certificate", "Third Keychain certificate"]
    
    var certificates = [SecCertificate]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.sectionHeaderHeight = 80
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.listPIVCertificates { result in
            switch result {
            case .success(let certificate):
                self.certificates = [certificate]
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UILabel()
        header.text = section == 0 ? "YubiKey" : "Keychain"
        header.font = UIFont.boldSystemFont(ofSize: 18)
  
        let text = UILabel()
        text.text = section == 0 ? "Certificates stored in your YubiKey" : "Public certificates saved to the Keychain of your iPhone"
        text.textColor = .darkGray
        text.numberOfLines = 0
        text.lineBreakMode = .byWordWrapping
        
        let stack = UIStackView(arrangedSubviews: [header, text])
        stack.axis = .vertical
        stack.spacing = 0
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20)
        stack.backgroundColor = .systemGray6
        return stack
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "foo")
        
        let title: String?
        if indexPath.section == 0 {
            let cert = certificates[indexPath.row]
            title = cert.commonName
        } else {
            title = keychainCerts[indexPath.row]
        }
        cell.textLabel?.text = title
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? certificates.count : keychainCerts.count
    }
    
}

extension SecCertificate {
    var commonName: String? {
        var name: CFString?
        SecCertificateCopyCommonName(self, &name)
        return name as String?
    }
}
