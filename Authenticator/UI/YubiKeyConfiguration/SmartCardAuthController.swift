//
//  PIVViewController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-18.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import Combine

@available(iOS 14.0, *)
class SmartCardAuthController: UITableViewController {
    
    let viewModel = SmartCardViewModel()
    var certificates = [SecCertificate]()
    var tokens = [SecCertificate]()
    
    deinit {
        print("deinit SmartCardAuthController")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.sectionHeaderHeight = 80
        tableView.estimatedRowHeight = 100
        tableView.allowsSelection = false
        tableView.register(CertificateCell.self, forCellReuseIdentifier: "CertificateCell")
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")

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
        
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if granted {
                print("Authorized to send notifications - show PIV certificate UI")
            } else {
                print("Not authorized to send notifications - show authorize notification UI")
            }
        }
        
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
        viewModel.tokensCallback = { result in
            switch result {
            case .success(let tokens):
                self.tokens = tokens
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            case .failure(let error):
                print(error)
            }
        }
        viewModel.update()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.certificatesCallback = nil
        viewModel.tokensCallback = nil
    }
    
    @objc func startNFC() {
        viewModel.startNFC()
        refreshControl?.endRefreshing()
    }
    
    func storeTokenCertificate(certificate: SecCertificate) {
        viewModel.storeTokenCertificate(certificate: certificate)
    }
    
    func removeTokenCertificate(certificate: SecCertificate) {
        viewModel.removeTokenCertificate(certificate: certificate)
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
        if indexPath.section == 0 {
            if certificates.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = viewModel.isKeyConnected ? "No SmartCard (PIV) certificates on this YubiKey." : "Insert a 5Ci YubiKey or pull down to scan for a NFC key."
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
                let certificate = certificates[indexPath.row]
                cell.name = certificate.commonName
                cell.action = { [weak self] in
                    self?.storeTokenCertificate(certificate: certificate)
                    self?.viewModel.update()
                }
                return cell
            }
        } else {
            if tokens.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = "There are no public certificates saved to the Keychain of this iPhone."
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
                let token = tokens[indexPath.row]
                cell.name = token.commonName
                cell.setSymbol(symbol: "minus.circle")
                cell.action = { [weak self] in
                    self?.removeTokenCertificate(certificate: token)
                    self?.viewModel.update()
                }
                return cell
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let rows = section == 0 ? certificates.count : tokens.count
        return rows == 0 ? 1 : rows
    }
}

private class MessageCell: UITableViewCell {
    private let messageLabel = UILabel()
    
    var message: String? {
        set {
            messageLabel.text = newValue
        }
        get {
            return messageLabel.text
        }
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.textAlignment = .center
        messageLabel.textColor = .gray
        messageLabel.font = messageLabel.font.withSize(15)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: -70),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant:20),
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
    }
    
    deinit {
        print("deinit MessageCell")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class CertificateCell: UITableViewCell {
    private let nameLabel = UILabel()
    private let button = UIButton(withSymbol: "apps.iphone.badge.plus")
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
