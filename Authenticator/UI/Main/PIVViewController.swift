//
//  PIVViewController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-18.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import Combine

class PIVViewController: UITableViewController {
    
    let viewModel = PIVViewModel()
    let keychainCerts = ["An important certificate", "Second Keychain certificate", "Third Keychain certificate"]
    var certificates = [SecCertificate]()
    
    deinit {
        print("deinit PIVViewController")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.sectionHeaderHeight = 80
        tableView.estimatedRowHeight = 100
        tableView.allowsSelection = false
        tableView.register(CertificateCell.self, forCellReuseIdentifier: "CertificateCell")
        
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            let refreshControl = UIRefreshControl()
            // setting background to refresh control changes behavior of spinner
            // and it gets dragged with pull rather than sticks to the top of the view
            refreshControl.backgroundColor = .clear
            refreshControl.addTarget(self, action:  #selector(startNFC), for: .valueChanged)
            self.refreshControl = refreshControl
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        viewModel.certificatesCallback = { result in
            switch result {
            case .success(let certificates):
                self.certificates = certificates
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.certificatesCallback = nil
    }
    
    @objc func startNFC() {
        viewModel.startNFC()
        refreshControl?.endRefreshing()
    }
    
    func copyCertificateToKeychain(certificate: SecCertificate) {
        viewModel.copyCertificateToKeychain(certificate: certificate)
    }
}


extension PIVViewController {
    
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
        if indexPath.section == 0 {
            let certificate = certificates[indexPath.row]
            cell.name = certificate.commonName
            cell.action = { [weak self] in
                self?.copyCertificateToKeychain(certificate: certificate)
            }
        } else {
            cell.name = keychainCerts[indexPath.row]
            cell.setSymbol(symbol: "minus.circle")
            cell.action = { [weak self] in
                print("remove from keychain: \(self?.keychainCerts[indexPath.row])")
            }
        }
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

class CertificateCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let button = UIButton(withSymbolName: "apps.iphone.badge.plus")
    var cancellable: Cancellable?
    
    var name: String? {
        set {
            nameLabel.text = newValue
        }
        get {
            return nameLabel.text
        }
    }
    var action: (() -> Void)? {
        set {
            guard let action = newValue else { return }
            self.cancellable = button.addHandler(for: .touchUpInside, block: action)
        }
        get {
            return nil
        }
    }
    
    func setSymbol(symbol: String) {
        button.setSymbol(symbol: symbol)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        isUserInteractionEnabled = true
        let stack = UIStackView(arrangedSubviews: [nameLabel, button])
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant:20),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        button.setSymbol(symbol: "apps.iphone.badge.plus")
        cancellable?.cancel()
    }
    
    deinit {
        print("deinit CertificateCell")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
