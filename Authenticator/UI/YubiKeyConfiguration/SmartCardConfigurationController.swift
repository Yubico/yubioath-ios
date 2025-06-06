/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import Combine
import SwiftUI
import OSLog

@available(iOS 14.0, *)

struct SmartCardConfigurationView: View {
    
    @State var presentHelpAlert: Bool = false
    
    var body: some View {
        SmartCardConfigurationWrapper()
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Smart card extension")
            .background(Color(.tableBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentHelpAlert.toggle()
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                }
            }
            .alert(String(localized: "Smart card extension", comment: "PIV extension info alert title"), isPresented: $presentHelpAlert, actions: {
                Button(role: .none) {
                    if let url = URL(string: "https://www.yubico.com/blog/yubico-pioneers-the-simplification-of-smartcard-support-on-mobile-for-ios/") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "Read more...", comment: "PIV extension read more alert title"))
                }
                Button(role: .cancel) {
                    presentHelpAlert.toggle()
                } label: {
                    Text("Cancel")
                }
            }, message: {
                Text("Other applications can use client certificates on your YubiKey for authentication and signing purposes.")
            })
    }
}

struct SmartCardConfigurationWrapper: UIViewControllerRepresentable {
    typealias UIViewControllerType = SmartCardConfigurationController
    
    func makeUIViewController(context: Context) -> SmartCardConfigurationController {
        return SmartCardConfigurationController(style: .insetGrouped)
    }
    
    func updateUIViewController(_ uiViewController: SmartCardConfigurationController, context: Context) { }
}

class SmartCardConfigurationController: UITableViewController {
    
    let viewModel = SmartCardViewModel()
    var certificates: [SmartCardViewModel.Certificate]? = nil
    var tokens = [SecCertificate]()
    let headerView = TableHeaderView()
    
    deinit {
        Logger.allocation.debug("SmartCardConfigurationController: deinit")
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
            if !granted {
                DispatchQueue.main.async {
                    let alertController = UIAlertController (title: String(localized: "Notifications disabled", comment: "PIV extension notifications alert title"),
                                                             message: String(localized: "The smart card extension requires notifications to be enabled for Yubico Authenticator. Enable it in the iOS Settings.", comment: "PIV extensions notifications alert message"),
                                                             preferredStyle: .alert)
                    
                    let cancelAction = UIAlertAction(title: String(localized: "Cancel"), style: .default) {_ in
                        self.dismiss(animated: true)
                    }
                    alertController.addAction(cancelAction)
                    
                    let settingsAction = UIAlertAction(title: String(localized: "Settings", comment: "PIV extension settings alert title"), style: .default) { (_) -> Void in
                        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                            return
                        }
                        if UIApplication.shared.canOpenURL(settingsUrl) {
                            UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                                self.dismiss(animated: true)
                            })
                        }
                    }
                    alertController.addAction(settingsAction)
                    
                    self.present(alertController, animated: true, completion: nil)
                }
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
                Logger.ctk.error("SmartCardConfigurationController: failed to fetch certificates: \(error)")
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
                Logger.ctk.error("SmartCardConfigurationController: failed to fetch tokens: \(error)")
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
            let alert = UIAlertController(title: String(localized: "Failed storing certificate", comment: "PIV extension storing error alert title"), message: "Error: \(error)", completion:{})
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
                cell.message = String(localized: "Insert YubiKey or pull down to activate NFC")
                return cell
            }
            
            if certificates.count == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
                cell.message = String(localized: "No certificates on YubiKey", comment: "PIV extension no certificates message")
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "CertificateCell", for: indexPath) as! CertificateCell
                let certificate = certificates[indexPath.row - 1]
                cell.name = "\(certificate.certificate.commonName ?? String(localized: "No name", comment: "PIV extension certificate with no name"))  (slot \(String(format: "%02X", certificate.slot.rawValue)))"
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
                cell.message = String(localized: "No public key certificates in keychain", comment: "PIV extension no certs in keychain")
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
            let configuration = UIImage.SymbolConfiguration(pointSize: 60, weight: .semibold)
            let device =  UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
            switch newValue {
            case .onYubiKey:
                icon.image = UIImage(named: "yubikey")?.withConfiguration(configuration)
                title.text = String(localized: "Certificates on YubiKey", comment: "PIV extension table cell header")
                text.text = String(localized: "Certificates on this YubiKey can be used to authenticate and sign requests from other applications if added to this \(device).", comment: "PIV extension no certs on yubikey message")
            case .onDevice:
                icon.image = UIImage(systemName: "iphone", withConfiguration: configuration)
                title.text = String(localized: "Public key certificates on \(device)", comment: "PIV extension no certs on device")
                text.text = String(localized: "These certificates have been added to this \(device) and can be used by other applications.", comment: "PIV extension certs on device")
            }
        }
    }

    let title: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .title2).withSymbolicTraits(.traitBold)
        return label
    }()
    
    let text: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        return label
    }()
    
    let icon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    let iconContainer: UIView = {
       let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemOrange
        container.layer.cornerRadius = 13
        return container
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.type = .onYubiKey
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.contentView.addSubview(iconContainer)
        self.contentView.addSubview(title)
        self.contentView.addSubview(text)
        self.iconContainer.addSubview(icon)

        NSLayoutConstraint.activate([
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 25),
            iconContainer.heightAnchor.constraint(equalToConstant: 60),
            iconContainer.widthAnchor.constraint(equalToConstant: 60),
            iconContainer.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            icon.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 10),
            icon.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: -10),
            icon.leftAnchor.constraint(equalTo: iconContainer.leftAnchor, constant: 10),
            icon.rightAnchor.constraint(equalTo: iconContainer.rightAnchor, constant: -10),
            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 20),
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
        Logger.allocation.debug("MessageCell: init")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
    }
    
    deinit {
        Logger.allocation.debug("MessageCell: deinit")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class CertificateCell: UITableViewCell {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()
    private let button: UIButton = {
        let button = UIButton(withSymbol: "plus.circle")
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()
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
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant:15),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -7),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
        ])
        Logger.allocation.debug("CertificateCell: init")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        button.setSymbol(symbol: "plus.circle")
        cancellable?.cancel()
    }
    
    deinit {
        Logger.allocation.debug("CertificateCell: deinit")
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
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
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
                label.text = String(localized: "Not Enabled", comment: "PIV extension not enabled message")
            case .enabled:
                imageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: configuration)
                imageView.tintColor = .systemGreen
                label.text = String(localized: "Enabled", comment: "PIV extension enabled message")
            }
        }
    }
}
