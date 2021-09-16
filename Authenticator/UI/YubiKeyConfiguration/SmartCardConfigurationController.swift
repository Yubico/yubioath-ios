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
    let headerView = TableHeaderView()
    
    deinit {
        print("deinit SmartCardAuthController")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        tableView.allowsSelection = false
        tableView.register(CertificateCell.self, forCellReuseIdentifier: "CertificateCell")
        tableView.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        tableView.register(HeaderCell.self, forCellReuseIdentifier: "HeaderCell")

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
        
        tableView.tableHeaderView = headerView
        NSLayoutConstraint.activate([
            headerView.widthAnchor.constraint(equalTo: tableView.widthAnchor)
        ])
        
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
                    self.headerView.status = tokens.count > 0 ? .enabled : .notEnabled
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
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath) as! HeaderCell
                cell.type = .onYubiKey
                return cell
            }
            
            guard let certificates = certificates else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = "Insert YubiKey or pull down to activate NFC"
                return cell
            }
            
            if certificates.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = "No certificates on YubiKey"
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
                let certificate = certificates[indexPath.row - 1]
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
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "HeaderCell", for: indexPath) as! HeaderCell
                cell.type = .onDevice
                return cell
            }
            
            if tokens.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = "No public key certificates in keychain"
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
                let token = tokens[indexPath.row - 1]
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
        return (rows == 0 ? 1 : rows) + 1
    }
}

private class HeaderCell: UITableViewCell {
    enum `Type` {
        case onYubiKey
        case onDevice
    }
    
    var type: Type {
        willSet {
            let configuration = UIImage.SymbolConfiguration(pointSize: 60)
            switch newValue {
            case .onYubiKey:
                icon.image = UIImage(named: "yubikey")?.withConfiguration(configuration)
                title.text = "Certificates on YubiKey".uppercased()
                text.text = "This extension enables other applications to use certificates stored on YubiKeys to authenticate or sign requests."
            case .onDevice:
                icon.image = UIImage(systemName: "iphone", withConfiguration: configuration)
                title.text = "Public key certificates on iPhone".uppercased()
                text.text = "A certificate on the YubiKey need its corresponding public certificate to be installed to the iPhone below."
            }
        }
    }

    let title: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel
        return label
    }()
    
    let text: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        return label
    }()
    
    let icon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .yubiBlue
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.type = .onYubiKey
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.contentView.addSubview(icon)
        self.contentView.addSubview(title)
        self.contentView.addSubview(text)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            icon.heightAnchor.constraint(equalToConstant: 45),
            icon.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 15),
            title.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10),
            title.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10),
            text.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            text.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10),
            text.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10),
            text.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant:10),
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
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
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant:10),
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

class TableHeaderView: UIView {
    
    private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private var label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(imageView)
        self.addSubview(label)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.topAnchor, constant: 40),
            imageView.heightAnchor.constraint(equalToConstant: 50),
            imageView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            label.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 10),
            label.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -10),
            label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -40),
            self.widthAnchor.constraint(equalToConstant: 200)
        ])
        
        defer {
            status = .notEnabled
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    enum Status {
        case enabled
        case notEnabled
    }
    
    var status: Status = .notEnabled {
        didSet {
            let configuration = UIImage.SymbolConfiguration(pointSize: 55)
            switch status {
            case .notEnabled:
                imageView.image = UIImage(systemName: "minus.circle.fill", withConfiguration: configuration)
                imageView.tintColor = .secondaryLabel
                label.text = "Not Enabled".uppercased()
            case .enabled:
                imageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)
                imageView.tintColor = .systemGreen
                label.text = "Enabled".uppercased()
            }
        }
    }
}
