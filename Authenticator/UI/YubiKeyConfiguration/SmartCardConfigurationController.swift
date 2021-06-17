//
//  SmartCardConfigurationController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-18.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import Combine

@available(iOS 14.0, *)
class SmartCardConfigurationController: UITableViewController {
    
    let viewModel = SmartCardViewModel()
    var certificates: [SmartCardViewModel.Certificate]? = nil
    var tokens = [SecCertificate]()
    
    deinit {
        print("deinit SmartCardAuthController")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.sectionHeaderHeight = UITableView.automaticDimension;
        tableView.estimatedSectionHeaderHeight = 80
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
        
        tableView.setupCustomHeaderView()
        
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
        let error = viewModel.storeTokenCertificate(certificate: certificate)
        if let error = error {
            let alert = UIAlertController(title: "Failed storing certificate", message: "Error: \(error)", completion:{})
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func removeTokenCertificate(certificate: SecCertificate) {
        viewModel.removeTokenCertificate(certificate: certificate)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 55)
        let image = UIImage(systemName: section == 0 ? "lock.circle.fill" : "key", withConfiguration: configuration)?.rotate(degrees: section == 0 ? 0 : -90)?.withTintColor(.yubiBlue)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        
        let header = UILabel()
        header.text = section == 0 ? "CERTIFICATES ON YUBIKEY" : "PUBLIC KEY CERTIFICATES ON IPHONE"
        header.font = UIFont.preferredFont(forTextStyle: .subheadline)
        header.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [imageView, header])
        stack.axis = .vertical
        stack.spacing = 25
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 35, leading: 15, bottom: 10, trailing: 15)
        return stack
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            guard let certificates = certificates else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = "Insert YubiKey or pull down to activate NFC"
                return cell
            }
            
            if certificates.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = "No Smart card (PIV) certificates on this YubiKey"
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
                let certificate = certificates[indexPath.row]
                cell.name = "\(certificate.certificate.commonName ?? "No name")  (slot \(String(format: "%02X", certificate.slot.rawValue)))"
                if !tokens.contains(certificate.certificate) {
                     cell.action = { [weak self] in
                        self?.storeTokenCertificate(certificate: certificate.certificate)
                        self?.viewModel.update()
                    }
                } else {
                    cell.setSymbol(symbol: "checkmark.circle")
                }
                return cell
            }
        } else {
            if tokens.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = "There are no public key certificates saved to the keychain of this iPhone"
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
        let rows = section == 0 ? certificates?.count ?? 0 : tokens.count
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
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.textColor = .secondaryLabel
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 45),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant:15),
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
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
    private let button = UIButton(withSymbol: "plus.circle")
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
        nameLabel.font = .preferredFont(forTextStyle: .body)
        isUserInteractionEnabled = true
        let stack = UIStackView(arrangedSubviews: [nameLabel, button])
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant:15),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        button.setSymbol(symbol: "plus.circle")
        cancellable?.cancel()
    }
    
    deinit {
        print("deinit CertificateCell")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


extension UITableView {
    func setupCustomHeaderView() {
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false

        let text = UILabel()
        text.translatesAutoresizingMaskIntoConstraints = false
        text.numberOfLines = 0
        text.font = .preferredFont(forTextStyle: .subheadline)
        text.textColor = .secondaryLabel
        text.lineBreakMode = .byWordWrapping
        text.text = "This extension enables other applications to use certificates stored on YubiKeys to authenticate or sign requests. A certificate on the YubiKey need its corresponding public certificate to be installed to the iPhone below."
        
        headerView.addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant:15),
            text.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -15),
            text.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 40),
            text.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 0),
        ])
        
        self.tableHeaderView = headerView
        NSLayoutConstraint.activate([
            headerView.widthAnchor.constraint(equalTo: self.widthAnchor)
        ])
    }
}
