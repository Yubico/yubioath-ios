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

import UIKit
import Combine
import CryptoTokenKit

class OATHViewController: UITableViewController {

    let viewModel = OATHViewModel()
    var detailView: OATHCodeDetailsView?
    
    @IBOutlet weak var menuButton: UIBarButtonItem!

    private var lastDidResignActiveTimeStamp: Date?
    private var cancellables = [Cancellable]()
    private var showWhatsNewButton = SettingsConfig.showWhatsNewText
    
    private var searchBar = SearchBar()
    private var applicationSessionObserver: ApplicationSessionObserver!
    
    private var backgroundView: UIView? {
        willSet {
            backgroundView?.removeFromSuperview()
            if let newValue = newValue {
                self.tableView.addSubview(newValue)
            }
        }
    }
    
    private var hintView: UIView?
    
    private func setupMenu(enabled: Bool) {
        self.menuButton.menu = nil
        self.menuButton.menu = UIMenu(title: "", children: [
            UIAction(title: "Add account",
                     image: UIImage(systemName: "qrcode"),
                     attributes: enabled ? [] : .disabled,
                     handler: { [weak self] _ in
                         guard let self = self else { return }
                         let storyboard = UIStoryboard(name: "AddCredential", bundle: nil)
                         let vc = storyboard.instantiateViewController(withIdentifier: "AddCredential")
                         self.present(vc, animated: true)
                     }),
            UIAction(title: "Configuration",
                     image: UIImage(systemName: "switch.2"),
                     attributes: enabled ? [] : [.disabled],
                     handler: { [weak self] _ in
                         guard let self = self else { return }
                         self.userFoundMenu()
                         self.performSegue(withIdentifier: "showConfiguration", sender: self)
                     }),
            UIAction(title: "About", image: UIImage(systemName: "questionmark.circle"), handler: { [weak self] _ in
                guard let self = self else { return }
                self.userFoundMenu()
                self.performSegue(withIdentifier: "ShowSettings", sender: self)
            })])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.viewModel.delegate = self
           
        setupMenu(enabled: YubiKitDeviceCapabilities.supportsISO7816NFCTags || viewModel.keyPluggedIn)
        setupRefreshControl()
        
        viewModel.wiredConnectionStatus { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.setupMenu(enabled: YubiKitDeviceCapabilities.supportsISO7816NFCTags || self.viewModel.keyPluggedIn)
            }
        }
        
        guard let image = UIImage(named: "NavbarLogo.png") else { fatalError() }
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = UIColor(named: "NavbarLogoColor")
        imageView.contentMode = .scaleAspectFit
        let aspectRatio = image.size.width / image.size.height
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 18),
            imageView.widthAnchor.constraint(equalToConstant: 18 * aspectRatio)
        ])
        self.navigationItem.titleView = imageView
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        // observe key plug-in/out changes even in background
        // to make sure we don't leave credentials on screen when key was unplugged
//        keySessionObserver = KeySessionObserver(accessoryDelegate: self, nfcDlegate: self)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        self.tableView.addGestureRecognizer(longPressGesture)
        
        applicationSessionObserver = ApplicationSessionObserver(delegate: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if .freVersion > SettingsConfig.lastFreVersionShown {
            self.performSegue(withIdentifier: .startTutorial, sender: self)
        } else if VersionHistoryViewController.shouldShowOnAppLaunch {
            let whatsNewController = VersionHistoryViewController()
            whatsNewController.titleText = "What's new in\nYubico Authenticator"
            whatsNewController.closeButtonText = "Continue"
            whatsNewController.closeBlock = { [weak self] in
                if SettingsConfig.isNFCOnAppLaunchEnabled {
                    self?.refreshData()
                }
            }
            self.present(whatsNewController, animated: true)
        }
        
        if let navigationView = self.navigationController?.view {
            let height = UIFontMetrics.default.scaledValue(for: 51)
            searchBar.frame = CGRect(x: 0, y: 0, width: navigationView.frame.width, height: height)
            searchBar.install(inTopOf: navigationView)
            searchBar.delegate = self
        }
        // update view in case if state has changed
        self.tableView.reloadData()
        refreshUIOnKeyStateUpdate()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.viewModel.stop()
    }
    
    
    // MARK: - Show search
    @IBAction func showSearch(_ sender: Any) {
        searchBar.isVisible = true
    }
    
    //
    // MARK: - Table view data source
    //
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        var sections = 0
        // only pinned accounts or only non pinned accounts
        if (viewModel.credentials.count > 0 && viewModel.pinnedCredentials.count == 0)
            || (viewModel.credentials.count == 0 && viewModel.pinnedCredentials.count > 0) {
            sections = 1
        }
        
        // pinned and non pinned accounts
        if viewModel.credentials.count > 0 && viewModel.pinnedCredentials.count > 0 {
            sections = 2
        }
        
        if sections > 0 {
            self.tableView.backgroundView = nil
            backgroundView = nil
            self.showHintView(false)
        } else {

            showBackgroundView()
            
            if viewModel.state == .loaded {
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    guard SettingsConfig.userHasFoundMenu == false
                            && self.viewModel.state == .loaded
                            && self.viewModel.credentials.count == 0
                    else { return }
                    self.showHintView(true)
                }
            } else {
                self.showHintView(false)
            }
        }
        return sections
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if viewModel.pinnedCredentials.count > 0 && section == 0 {
            return "Pinned"
        }
        
        if viewModel.pinnedCredentials.count == 0 && section == 0 {
            return "Accounts"
        }
        
        return "Accounts"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && viewModel.pinnedCredentials.count > 0 {
            return viewModel.pinnedCredentials.count
        }
        
        return viewModel.credentials.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CredentialCell", for: indexPath) as! CredentialTableViewCell
        cell.viewModel = viewModel
        let credential = credentialAt(indexPath)
        cell.updateView(credential: credential)
        
        let backgroundContainerView = UIView()
        let backgroundView = UIView()
        backgroundView.layer.cornerRadius = 10
        backgroundView.backgroundColor = UIColor(named: "TableSelection")
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainerView.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: backgroundContainerView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: backgroundContainerView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: backgroundContainerView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: backgroundContainerView.bottomAnchor)
        ])
        cell.selectedBackgroundView = backgroundContainerView
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        _ = searchBar.resignFirstResponder()
        let credential = credentialAt(indexPath)
        let details = OATHCodeDetailsView(credential: credential, viewModel: viewModel, parentViewController: self)
        let rect = tableView.rectForRow(at: indexPath)
        details.present(from: CGPoint(x: rect.midX, y: rect.midY))
        self.detailView = details
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return false
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if #available(iOS 14.0, *) {
            if segue.identifier == "handleTokenRequest" {
                guard let tokenRequestController = segue.destination as? TokenRequestViewController, let userInfo = sender as? [AnyHashable: Any] else { assertionFailure(); return }
                tokenRequestController.userInfo = userInfo
            }
        }
        
        if segue.identifier == .editCredential {
            guard let navigationController = segue.destination as? UINavigationController,
                  let destination = navigationController.topViewController as? EditCredentialController,
                  let credential = sender as? Credential else { assertionFailure(); return }
            destination.credential = credential
            destination.viewModel = viewModel
        }

        if segue.identifier == .startTutorial {
            guard let navigationController = segue.destination as? UINavigationController,
                  let freViewController = navigationController.topViewController as? TutorialViewController else { assertionFailure(); return }
            // passing userFreVersion and then setting current freVersion to userDefaults.
            freViewController.userFreVersion = SettingsConfig.lastFreVersionShown
            SettingsConfig.lastFreVersionShown = .freVersion
        }
    }
    
    @IBAction func unwindToMainViewController(segue: UIStoryboardSegue) {
        if let sourceViewController = segue.source as? AddCredentialController, let credential = sourceViewController.credential {
            // Add a new credential to table.
            viewModel.addCredential(credential: credential, requiresTouch: sourceViewController.requiresTouch)
        }
    }
    
    // MARK: - private methods
    @objc private func handleLongPress(longPressGesture: UILongPressGestureRecognizer) {
        guard longPressGesture.state == .began else { return }
        let location = longPressGesture.location(in: self.tableView)
        let indexPath = self.tableView.indexPathForRow(at: location)
        guard let indexPath = indexPath else {
            return
        }
        let credential = credentialAt(indexPath)
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }

        if credential.requiresRefresh {
            viewModel.calculate(credential: credential) { [self] _ in
                DispatchQueue.main.async {
                    let cell = self.tableView.cellForRow(at: indexPath) as? CredentialTableViewCell
                    cell?.animateCode()

                }
                self.viewModel.copyToClipboard(credential: credential)
            }
        } else {
            let cell = self.tableView.cellForRow(at: indexPath) as? CredentialTableViewCell
            cell?.animateCode()
            viewModel.copyToClipboard(credential: credential)
        }
    }
    
    private func refreshCredentials() {
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey || YubiKitDeviceCapabilities.supportsSmartCardOverUSBC {
            if viewModel.keyPluggedIn {
                viewModel.calculateAll()
                tableView.reloadData()
            } else {
                // if YubiKey is unplugged do not show any OTP codes
                viewModel.cleanUp()
            }
        } else {
#if DEBUG
            // show some credentials on emulator
            viewModel.emulateSomeRecords()
#endif
        }

        tableView.reloadData()
    }
    
    @objc func refreshData() {
        viewModel.calculateAll()
        refreshControl?.endRefreshing()
    }
    
    //
    // MARK: - UI Setup
    //
    
    private func setupRefreshControl() {
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            let refreshControl = UIRefreshControl()
            // setting background to refresh control changes behavior of spinner
            // and it gets dragged with pull rather than sticks to the top of the view
            refreshControl.backgroundColor = .clear
            refreshControl.addTarget(self, action:  #selector(refreshData), for: .valueChanged)
            self.refreshControl = refreshControl
        }
    }

    private func refreshUIOnKeyStateUpdate() {
        #if !targetEnvironment(simulator)
            // allow to see add option on emulator and switch to manual add credential view
            navigationItem.rightBarButtonItem?.isEnabled = true
        #else
            navigationItem.rightBarButtonItem?.isEnabled = viewModel.keyPluggedIn || YubiKitDeviceCapabilities.supportsISO7816NFCTags
        #endif
        
        refreshCredentials()
    }
    
    private func userFoundMenu() {
        showHintView(false)
        SettingsConfig.userHasFoundMenu = true
    }
    
    private func showHintView(_ visible: Bool) {
        if !visible {
            hintView?.removeFromSuperview()
            hintView = nil
            return
        }
        guard hintView == nil else { return }
        let hintView = UIView()
        hintView.alpha = 0
        let label = UILabel()
        label.text = "Add accounts here"
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.sizeToFit()
        hintView.addSubview(label)
        let imageView = UIImageView()
        imageView.tintColor = .secondaryLabel
        let configuration = UIImage.SymbolConfiguration(pointSize: 20)
        let image = UIImage(systemName: "arrow.turn.right.up")?.withConfiguration(configuration)
        imageView.image = image
        imageView.frame.size = image?.size ?? .zero
        imageView.frame.origin = CGPoint(x: label.frame.width + 5, y: -7)
        hintView.addSubview(imageView)
        hintView.frame = CGRect(x: self.view.frame.width - (label.frame.width + 5 + imageView.frame.width + 18) , y: 20, width: label.frame.width + 5 + imageView.frame.width
                                , height: label.frame.height)
        self.hintView = hintView
        self.view.addSubview(hintView)
        
        UIView.animate(withDuration: 0.3) {
            hintView.alpha = 1
        }
    }
    
    // MARK: - Custom empty table view
    private func showBackgroundView() {
        self.tableView.setContentOffset(.zero, animated: false)
        
        let backgroundView = UIView()
        backgroundView.frame.size = tableView.frame.size
        backgroundView.center = tableView.center
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(contentView)

        let imageView = UIImageView()
        imageView.contentMode = .bottom
        imageView.image = getBackgroundImage()?.withRenderingMode(.alwaysTemplate).withConfiguration(UIImage.SymbolConfiguration(pointSize: 100))
        imageView.tintColor = UIColor.yubiBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.text = getTitle()
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        let whatsNewButton = UIButton()
        whatsNewButton.translatesAutoresizingMaskIntoConstraints = false
        whatsNewButton.isHidden = !showWhatsNewButton
        cancellables.append(whatsNewButton.addHandler(for: .touchUpInside, block: { [weak self] in
            SettingsConfig.didShowWhatsNewText()
            let whatsNewController = VersionHistoryViewController()
            whatsNewController.titleText = "What's new in\nYubico Authenticator"
            self?.present(whatsNewController, animated: true)
        }))
        if #available(iOS 15, *) {
            var see = AttributedString("See ")
            see.foregroundColor = .secondaryLabel
            see.font = .preferredFont(forTextStyle: .footnote)
            var whatsNew = AttributedString("what's new ")
            whatsNew.foregroundColor = .yubiBlue
            whatsNew.font = .preferredFont(forTextStyle: .footnote)
            var inThisVersion = AttributedString("in this version")
            inThisVersion.foregroundColor = .secondaryLabel
            inThisVersion.font =  .preferredFont(forTextStyle: .footnote)
            let attributedString = NSAttributedString(see + whatsNew + inThisVersion)
            whatsNewButton.setAttributedTitle(attributedString, for: .normal)
        } else {
            whatsNewButton.setTitle("See what's new in this version", for: .normal)
            whatsNewButton.setTitleColor(.yubiBlue, for: .normal)
            whatsNewButton.titleLabel?.font = .preferredFont(forTextStyle: .footnote)
        }
        backgroundView.addSubview(whatsNewButton)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 25),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 600),
            contentView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor, constant: -100), // we need to move the anchor up a bit since the table extends below the screen
            contentView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            whatsNewButton.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            whatsNewButton.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -150)
        ])
        
        self.backgroundView = backgroundView
    }
       
    private func getBackgroundImage() -> UIImage? {
        switch viewModel.state {
        case .loaded:
            // No accounts view
            return viewModel.hasFilter ? UIImage(nameOrSystemName: "person.crop.circle.badge.questionmark") :  UIImage(nameOrSystemName: "person.crop.circle")
        case .notSupported:
            return UIImage(nameOrSystemName: "info.circle")
        default:
            // YubiKey image
            return UIImage(named: "yubikey")
        }
    }
    
    private func getTitle() -> String? {
        switch viewModel.state {
        case .idle:
            if viewModel.keyPluggedIn {
                return nil
            } else {
                return YubiKitDeviceCapabilities.supportsISO7816NFCTags ? "Insert YubiKey or pull down to activate NFC" : "Insert YubiKey"
            }
        case .loaded:
            return viewModel.hasFilter ? "No matching accounts" : "No accounts on YubiKey"
        case .notSupported:
            if UIDevice.current.userInterfaceIdiom == .pad {
                return "Yubico Authenticator requires iPadOS 16 for iPad with USB-C port."
            } else {
                return "Yubico Authenticator is not supported on this device."
            }
        default:
            return nil
        }
    }
}

extension OATHViewController: CredentialViewModelDelegate {
    
    // MARK: - CredentialViewModelDelegate
    
    func showAlert(title: String, message: String?) {
        self.showAlertDialog(title: title, message: message, okHandler:  { [weak self] () -> Void in
            self?.dismiss(animated: true, completion: nil)
        })
    }

    func onError(error: Error) {
        let nsError = error as NSError
        if nsError.domain == TKErrorDomain && nsError.code == -2 {
            showAlert(title: "Require Touch currently unsupported on iPad", message: "Due to a limitation in the current USB smart card implementation for iPad, require touch unfortunately does not yet work on this device.")
            return
        }
        showAlert(title: "Something went wrong", message: error.localizedDescription)
    }
    
    func onOperationCompleted(operation: OperationName) {
        switch operation {
        case .setCode:
            self.showAlertDialog(title: "Success", message: "The password has been successfully set", okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        case .reset:
            self.showAlertDialog(title: "Success", message: "The application has been successfully reset", okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
                self?.tableView.reloadData()
            })
        case .getConfig:
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "ShowTagSettings", sender: self)
            }
        case .getKeyVersion:
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "ShowDeviceInfo", sender: self)
            }
        case .calculateAll, .cleanup, .filter:
            detailView?.dismiss()
            detailView = nil
            self.tableView.reloadData()
        default:
            // other operations do not change list of credentials
            break
        }
    }
    
    func onShowToastMessage(message: String) {
        self.displayToast(message: message)
    }
    
    func onCredentialDelete(credential: Credential) {
        self.tableView.reloadData()
    }
    
    func collectPasswordPreferences(completion: @escaping (PasswordSaveType) -> Void) {
        let passwordActionSheet = UIAlertController { type in
            completion(type)
        }
        DispatchQueue.main.async {
            self.present(passwordActionSheet, animated: true)
        }
    }

    func collectPassword(isPasswordEntryRetry: Bool, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let passwordEntryAlert = UIAlertController(passwordEntryType: isPasswordEntryRetry ? .retryPassword : .password) { password in
                completion(password)
            }
            self.present(passwordEntryAlert, animated: true)
        }
    }
    
    private func credentialAt(_ indexPath: IndexPath) -> Credential {
        if viewModel.pinnedCredentials.count > 0 && indexPath.section == 0 {
            return viewModel.pinnedCredentials[indexPath.row]
        } else {
            return viewModel.credentials[indexPath.row]
        }
    }
}

// MARK: ApplicationSessionObserverDelegate
extension OATHViewController: ApplicationSessionObserverDelegate {
    func didEnterBackground() {
        viewModel.cleanUp()
    }
    
    func willResignActive() {
        lastDidResignActiveTimeStamp = Date()
    }
    
    func didBecomeActive() {
        guard !VersionHistoryViewController.shouldShowOnAppLaunch else { return }
        
        if SettingsConfig.isNFCOnAppLaunchEnabled && !viewModel.didNFCEndRecently {
            guard let lastDidResignActiveTimeStamp = lastDidResignActiveTimeStamp else {
                refreshData()
                return
            }
            
            if Date() > lastDidResignActiveTimeStamp.addingTimeInterval(10) {
                if let presented = presentedViewController {
                    presented.dismiss(animated: false) {
                        self.refreshData()
                    }
                } else {
                    refreshData()
                }
            }
        }
    }
}

extension OATHViewController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        view.window?.rootViewController?.dismiss(animated: false, completion: nil)
        performSegue(withIdentifier: "handleTokenRequest", sender: response.notification.request.content.userInfo)
        completionHandler()
    }
}

extension OATHViewController: SearchBarDelegate {
    func searchBarDidChangeText(_ text: String) {
        viewModel.applyFilter(filter: text)
    }
    func searchBarDidCancel() {
        viewModel.applyFilter(filter: nil)
    }
}

extension SearchBar {
    func install(inTopOf view: UIView) {
        self.frame.origin.y = -self.frame.size.height
        view.addSubview(self)
    }
}

extension YubiKitDeviceCapabilities {
    static var isDeviceSupported: Bool {
        return Self.supportsMFIAccessoryKey || Self.supportsISO7816NFCTags || Self.supportsSmartCardOverUSBC
    }
    
}
