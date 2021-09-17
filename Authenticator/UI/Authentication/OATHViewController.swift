//
//  MainViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class OATHViewController: UITableViewController {

    let viewModel = OATHViewModel()
    let passwordPreferences = PasswordPreferences()
    var passwordCache = PasswordCache()
    let secureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    
    var detailView: OATHCodeDetailsView?
    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var searchButton: UIBarButtonItem!

    private var searchBar = UISearchBar()
    private var applicationSessionObserver: ApplicationSessionObserver!
    private var credentailToAdd: YKFOATHCredentialTemplate?
    
    private var coverView: UIView?
    
    private var backgroundView: UIView? {
        willSet {
            backgroundView?.removeFromSuperview()
            if let newValue = newValue {
                self.tableView.addSubview(newValue)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.viewModel.delegate = self
        setupRefreshControl()
        if #available(iOS 14.0, *) {
            let oathMenu = UIMenu(title: "", options: .displayInline, children: [
                UIAction(title: "Scan QR code", image: UIImage(systemName: "qrcode"), handler: { [weak self] _ in
                    self?.scanQR()
                }),
                UIAction(title: "Add account", image: UIImage(systemName: "square.and.pencil"), handler: { [weak self] _ in
                    self?.performSegue(withIdentifier: .addCredentialSequeID, sender: self)
                })
            ])
            let configurationMenu = UIMenu(title: "", options: .displayInline, children: [
                UIAction(title: "Configuration", image: UIImage(systemName: "switch.2"), handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "showConfiguration", sender: self)
                }),
                UIAction(title: "About", image: UIImage(systemName: "questionmark.circle"), handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "ShowSettings", sender: self)
                })
            ])
            
            menuButton.menu = UIMenu(title: "", children: [oathMenu, configurationMenu])
        } else {
            menuButton.target = self
            menuButton.action = #selector(showLegacyMenu(_:))
        }
        
#if !DEBUG
        if !YubiKitDeviceCapabilities.supportsMFIAccessoryKey && !YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            let message = "This \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone") has no support for NFC nor a Lightning port for the YubiKey to connect to."
            self.showAlertDialog(title: "Device not supported", message: message)
        }
#endif
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        // observe key plug-in/out changes even in background
        // to make sure we don't leave credentials on screen when key was unplugged
//        keySessionObserver = KeySessionObserver(accessoryDelegate: self, nfcDlegate: self)
        
        applicationSessionObserver = ApplicationSessionObserver(delegate: self)
    }
    
    @objc func showLegacyMenu(_ sender: AnyObject) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Scan QR code", style: .default, handler: { [weak self] _ in
            self?.scanQR()
        }))
        alert.addAction(UIAlertAction(title: "Add manually", style: .default, handler: { [weak self] _ in
            self?.performSegue(withIdentifier: .addCredentialSequeID, sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Clear passwords", style: .default, handler: { [weak self] _ in
            self?.showWarning(title: "Clear stored passwords?", message: "If you have set a password on any of your YubiKeys you will be prompted for it the next time you use those YubiKeys on this Yubico Authenticator.", okButtonTitle: "Clear") { () -> Void in
                self?.removeStoredPasswords()
            }
        }))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { [weak self] _ in
            let alert = UIAlertController(title: "Not implemented yet", message: nil, completion: {})
            self?.present(alert, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Configuration", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.performSegue(withIdentifier: "showConfiguration", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "About", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            self.performSegue(withIdentifier: "ShowSettings", sender: self)
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // UserDefaults will store the latest FRE version and latest 'What's New' version that were shown to user.
        // For every new FRE or 'What's New' in the future releases we're going to increment .freVersion and .whatsNewVersion by 1.
        if .freVersion > SettingsConfig.lastFreVersionShown {
            self.performSegue(withIdentifier: .startTutorial, sender: self)
        }/* else if .whatsNewVersion > SettingsConfig.lastWhatsNewVersionShown {
            self.performSegue(withIdentifier: "ShowWhatsNew", sender: self)
        }*/
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationView = self.navigationController?.view {
            searchBar.frame = CGRect(x: 0, y: 0, width: navigationView.frame.width, height: 44)
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
        searchBar.showInTop(true)
    }
    
    //
    // MARK: - Add credential
    //
    @IBAction func onAddCredentialClick(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if YubiKitDeviceCapabilities.supportsQRCodeScanning {
            // if QR codes are unavailable on device disable option
            actionSheet.addAction(UIAlertAction(title: "Scan QR code", style: .default) { [weak self]  (action) in
                self?.scanQR()
            })
        }
        actionSheet.addAction(UIAlertAction(title: "Enter manually", style: .default) { [weak self]  (action) in
            self?.performSegue(withIdentifier: .addCredentialSequeID, sender: self)
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] (action) in
            self?.dismiss(animated: true, completion: nil)
        })
        
        // The action sheet requires a presentation popover on iPad.
        if UIDevice.current.userInterfaceIdiom == .pad {
            actionSheet.modalPresentationStyle = .popover
            actionSheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    //
    // MARK: - Table view data source
    //
    override func numberOfSections(in tableView: UITableView) -> Int {
        if viewModel.credentials.count > 0 {
            self.navigationItem.titleView = nil
            self.title = "Accounts"
            self.searchButton.isEnabled = true
            self.tableView.backgroundView = nil
            backgroundView = nil
            return 1
        } else {
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

            self.searchButton.isEnabled = false
            showBackgroundView()
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.credentials.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CredentialCell", for: indexPath) as! CredentialTableViewCell
        cell.viewModel = viewModel
        let credential = viewModel.credentials[indexPath.row]
        let isFavorite = self.viewModel.isFavorite(credential: credential)
        cell.updateView(credential: credential, isFavorite: isFavorite)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let credential = viewModel.credentials[indexPath.row]
            let details = OATHCodeDetailsView(credential: credential, viewModel: viewModel, parentViewController: self)
            let rect = tableView.rectForRow(at: indexPath)
            details.present(from: CGPoint(x: rect.midX, y: rect.midY))
            self.detailView = details
        }
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
            SettingsConfig.lastWhatsNewVersionShown = .whatsNewVersion
        }
        
        if segue.identifier == .addCredentialSequeID {
            guard let navigationController = segue.destination as? UINavigationController,
                  let addViewController = navigationController.topViewController as? AddCredentialController else { assertionFailure(); return }
            if let credential = credentailToAdd {
                addViewController.displayCredential(details: credential)
            }
            credentailToAdd = nil
        }
    }
    
    @IBAction func unwindToMainViewController(segue: UIStoryboardSegue) {
        if let sourceViewController = segue.source as? AddCredentialController, let credential = sourceViewController.credential {
            // Add a new credential to table.
            viewModel.addCredential(credential: credential, requiresTouch: sourceViewController.requiresTouch)
        }
    }
    
    // MARK: - private methods
    private func scanQR() {
        YKFQRReaderSession.shared.scanQrCode(withPresenter: self) {
            [weak self] (payload, error) in
            guard self != nil else {
                return
            }
            guard error == nil else {
                self?.onError(error: error!)
                return
            }
            
            // This is an URL conforming to Key URI Format specs.
            guard let url = URL(string: payload!) else {
                self?.onError(error: KeySessionError.invalidUri)
                return
            }
            
            guard let credential = YKFOATHCredentialTemplate(url: url) else {
                self?.onError(error: KeySessionError.invalidCredentialUri)
                return
            }
            
            self?.credentailToAdd = credential
            self?.performSegue(withIdentifier: .addCredentialSequeID, sender: self)
        }
    }

    private func refreshCredentials() {
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
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
    
    // MARK: - Custom empty table view
    private func showBackgroundView() {
        self.tableView.setContentOffset(.zero, animated: false)
        
        let backgroundView = UIView()
        backgroundView.frame.size = tableView.frame.size
        backgroundView.center = tableView.center

        let imageView = UIImageView()
        imageView.contentMode = .bottom
        imageView.image = getBackgroundImage()?.withRenderingMode(.alwaysTemplate).withConfiguration(UIImage.SymbolConfiguration(pointSize: 100))
        imageView.tintColor = UIColor.yubiBlue
        backgroundView.embedView(imageView, edgeInsets: UIEdgeInsets(top: 0, left: 0, bottom: 140, right: 0), pinToEdges: [], layoutPriority: .defaultHigh)
        
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        label.text = getTitle()
        backgroundView.embedView(label, edgeInsets: UIEdgeInsets(top: 0, left: 30, bottom: 20, right: 30), pinToEdges: [.left, .right])
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(OATHViewController.onBackgroundClick))
        backgroundView.isUserInteractionEnabled = viewModel.state == .loaded && !viewModel.hasFilter
        backgroundView.addGestureRecognizer(gestureRecognizer)

        self.backgroundView = backgroundView
    }
       
    private func getBackgroundImage() -> UIImage? {
        switch viewModel.state {
            case .loaded:
                // No accounts view
            return viewModel.hasFilter ? UIImage(nameOrSystemName: "person.crop.circle.badge.questionmark") :  UIImage(nameOrSystemName: "person.crop.circle.badge.plus")
            case .notSupported:
                return UIImage(nameOrSystemName: "exclamationmark.circle")
           default:
                // YubiKey image
                return UIImage(named: "yubikey")
        }
    }
    
    private func getTitle() -> String? {
        switch viewModel.state {
            case .idle:
                return viewModel.keyPluggedIn || !YubiKitDeviceCapabilities.supportsISO7816NFCTags ? nil :"Insert YubiKey or pull down to activate NFC"
            case .loaded:
            return viewModel.hasFilter ? "No matching accounts" : "No accounts on YubiKey"
            case .notSupported:
                return "This \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone") is not supported since it has no NFC reader nor a Lightning port for the YubiKey to connect to. To use Yubico Authenticator for iOS you need an iPhone or iPad with a Lightning port."
            default:
                return nil
        }
    }
    
    @objc func onBackgroundClick() {
        switch viewModel.state {
            case .loaded:
                self.onAddCredentialClick(self)
            case .locked:
                let error = NSError(domain: "", code: Int(YKFOATHErrorCode.authenticationRequired.rawValue), userInfo:nil)
                self.onError(error: error)
            default:
                break
        }
    }
}
extension OATHViewController: CredentialViewModelDelegate {
    
    // MARK: - CredentialViewModelDelegate
    
    /*! Delegate method that invoked when any operation failed
     * Operation could be from YubiKit operations (e.g. calculate) or QR scanning (e.g. scan code)
     */
    func onError(error: Error) {
        // not sure we will need this
        print("Got error: \(error)")
    }
    
    /*! Delegate method that invoked when any operation succeeded
     * Operation could be from YubiKit (e.g. calculate) or local (e.g. filter)
     */
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
            self.tableView.reloadData()
        default:
            // other operations do not change list of credentials
            break
        }
    }
    
    func onShowToastMessage(message: String) {
        self.displayToast(message: message)
    }
    
    func onCredentialDelete(indexPath: IndexPath) {
        // Removal of last element in section requires to remove the section.
        if self.viewModel.credentials.count == 0 {
            self.tableView.deleteSections([0], with: .fade)
        } else {
            self.tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    func didValidatePassword(_ password: String, forKey key: String) {
        // Cache password in memory
        passwordCache.setPassword(password, forKey: key)
        
        // Check if we should save password in keychain
        if !self.passwordPreferences.neverSavePassword(keyIdentifier: key) {
            self.secureStore.getValue(for: key) { result in
                let currentPassword = try? result.get()
                if password != currentPassword {
                    let passwordActionSheet = UIAlertController(passwordPreferences: self.passwordPreferences) { type in
                        self.passwordPreferences.setPasswordPreference(saveType: type, keyIdentifier: key)
                        if self.passwordPreferences.useSavedPassword(keyIdentifier: key) || self.passwordPreferences.useScreenLock(keyIdentifier: key) {
                            do {
                                try self.secureStore.setValue(password, useAuthentication: self.passwordPreferences.useScreenLock(keyIdentifier: key), for: key)
                            } catch let e {
                                self.passwordPreferences.resetPasswordPreference(keyIdentifier: key)
                                self.showAlertDialog(title: "Password was not saved", message: e.localizedDescription)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self.present(passwordActionSheet, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    func cachedPasswordFor(keyId: String, completion: @escaping (String?) -> Void) {
        if let password = passwordCache.password(forKey: keyId) {
            completion(password)
            return
        }
        self.secureStore.getValue(for: keyId) { result in
            let password = try? result.get()
            completion(password)
            return
        }
    }
    
    func passwordFor(keyId: String, isPasswordEntryRetry: Bool, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let passwordEntryAlert = UIAlertController(passwordEntryType: isPasswordEntryRetry ? .retryPassword : .password) { password in
                completion(password)
            }
            self.present(passwordEntryAlert, animated: true)
        }
    }
    
    private func removeStoredPasswords() {
        passwordPreferences.resetPasswordPreferenceForAll()
        do {
            try secureStore.removeAllValues()
            self.showAlertDialog(title: "Success", message: "Stored passwords have been cleared from this phone.", okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        } catch let e {
            self.showAlertDialog(title: "Failed to clear stored passwords.", message: e.localizedDescription, okHandler:  { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            })
        }
    }
}

// MARK: ApplicationSessionObserverDelegate
extension OATHViewController: ApplicationSessionObserverDelegate {
    func didEnterBackground() {
        viewModel.cleanUp()
    }
    
    func willResignActive() {
        return // disable cover view until we can stop it from showing when we start nfc scanning
        let coverView = UIView()
        coverView.backgroundColor = .background // UIColor(named: "DetailsBackground")
        coverView.frame.size = self.view.bounds.size
        coverView.center = tableView.center
        
        let logo = UIImageView(image: UIImage(named: "LogoText"))

        coverView.embedView(logo, pinToEdges: [])
        // Add cover to superview to avoid it being offset depending of the table scroll view
        tableView.superview?.addSubview(coverView)
        self.coverView = coverView
    }
    
    func didBecomeActive() {
        coverView?.removeFromSuperview()
        coverView = nil
    }
    
}

// MARK: - UISearchBarDelegate
extension OATHViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.showInTop(false)
        searchBar.text = nil
        viewModel.applyFilter(filter: nil)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        print(searchText)
        viewModel.applyFilter(filter: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.showInTop(false)
        viewModel.applyFilter(filter: nil)
    }
    
    func searchBarShouldEndEditing(_ searchBar: UISearchBar) -> Bool {
        searchBar.text = nil
        viewModel.applyFilter(filter: nil)
        return true
    }
}

extension OATHViewController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        view.window?.rootViewController?.dismiss(animated: false, completion: nil)
        performSegue(withIdentifier: "handleTokenRequest", sender: response.notification.request.content.userInfo)
        completionHandler()
    }
}

// MARK: - UISerchBar extension
extension UISearchBar {
    func install(inTopOf view: UIView) {
        self.placeholder = "Search accounts"
        self.showsCancelButton = true
        self.frame.origin.y = -self.frame.size.height
        view.addSubview(self)
        self.returnKeyType = .done
        self.tintColor = .yubiBlue
        self.backgroundImage = UIImage()
        self.backgroundColor = UIColor(named: "SystemNavigationBar")!
    }
    
    func showInTop(_ isVisible: Bool) {
        let window = UIApplication.shared.windows[0]
        let topPadding = window.safeAreaInsets.top
        if isVisible {
            self.becomeFirstResponder()
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.frame.origin.y = topPadding
            }
        } else {
            self.resignFirstResponder()
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.frame.origin.y = -self.frame.size.height
            }
        }
    }
}
