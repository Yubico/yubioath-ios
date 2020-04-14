//
//  MainViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class MainViewController: BaseOATHVIewController {

    private var credentialsSearchController: UISearchController!
    private var applicationSessionObserver: ApplicationSessionObserver!
    private var keySessionObserver: KeySessionObserver!
    private var credentailToAdd: YKFOATHCredential?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupCredentialsSearchController()
        setupNavigationBar()
        setupRefreshControl()
        
#if !DEBUG
        if !YubiKitDeviceCapabilities.supportsMFIAccessoryKey && !YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            let error = KeySessionError.notSupported
            self.showAlertDialog(title: "", message: error.localizedDescription)
        }
#endif
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        // observe key plug-in/out changes even in background
        // to make sure we don't leave credentials on screen when key was unplugged
        keySessionObserver = KeySessionObserver(accessoryDelegate: self, nfcDlegate: self)
        
        applicationSessionObserver = ApplicationSessionObserver(delegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // UserDefaults will store the latest FRE version and latest 'What's New' version that were shown to user.
        // For every new FRE or 'What's New' in the future releases we're going to increment .freVersion and .whatsNewVersion by 1.
        if .freVersion > SettingsConfig.lastFreVersionShown {
            self.performSegue(withIdentifier: "StartFRE", sender: self)
        } else if .whatsNewVersion > SettingsConfig.lastWhatsNewVersionShown {
            self.performSegue(withIdentifier: "ShowWhatsNew", sender: self)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshUIOnKeyStateUpdate()
    }
    
    deinit {
        keySessionObserver.observeSessionState = false
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
            self.tableView.backgroundView = nil
            self.tableView.separatorStyle = .singleLine
            return 1
        } else {
            showBackgroundView()
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.credentials.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CredentialCell", for: indexPath) as! CredentialTableViewCell
        let credential = viewModel.credentials[indexPath.row]
        let isFavorite = self.viewModel.isFavorite(credential: credential)
        cell.updateView(credential: credential, isFavorite: isFavorite)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let credential = viewModel.credentials[indexPath.row]
            if credential.type == .HOTP && credential.activeTime > 5 {
                // refresh HOTP on touch
                print("HOTP active for \(String(format:"%f", credential.activeTime)) seconds")
                viewModel.calculate(credential: credential)
            } else if credential.code.isEmpty || credential.remainingTime <= 0 {
                // refresh items that require touch
                viewModel.calculate(credential: credential)
            } else {
                viewModel.copyToClipboard(credential: credential)
            }
        }
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { _, _, _ in
             // Delete the row from the data source
            let credential = self.viewModel.credentials[indexPath.row]
             // show warning that user will delete credential to preven accident removals
             // we also won't update UI until
             // the actual removal happen (for example when user tapped key over NFC)
             let name = credential.issuer?.isEmpty == false ? "\(credential.issuer!) (\(credential.account))" : credential.account
             self.showWarning(title: "Delete \(name)?", message: "This will permanently delete the credential from the YubiKey, and your ability to generate codes for it", okButtonTitle: "Delete") { [weak self] () -> Void in
                 self?.viewModel.deleteCredential(credential: credential)
            }
        }
            
        deleteAction.image = UIImage.trash
        deleteAction.backgroundColor = .red
               
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let credential = self.viewModel.credentials[indexPath.row]
        var action = UIContextualAction()
        if self.viewModel.isFavorite(credential: credential) {
            // Remove credential from the set of Favorites.
            action = UIContextualAction(style: .normal, title: "Remove from Favorites") { [weak self] _, _, _ in
                guard let self = self else {
                    return
                }
                let destinationIndexPath = self.viewModel.removeFavorite(credential: credential)
                self.animateAction(indexPath: indexPath, destinationIndexPath: destinationIndexPath)
            }

            action.image = UIImage.star
        } else {
            // Add credential to the set of Favorites.
            action = UIContextualAction(style: .normal, title: "Add to Favorites") { [weak self] _, _, _ in
                guard let self = self else {
                    return
                }
                let destinationIndexPath = self.viewModel.addFavorite(credential: credential)
                self.animateAction(indexPath: indexPath, destinationIndexPath: destinationIndexPath)
            }
            
            action.backgroundColor = UIColor(named: "Favorite")
            action.image = UIImage.starFilled
        }
        
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    // Animation for moving row when pin/unpin favorites to/from the top.
    private func animateAction(indexPath: IndexPath, destinationIndexPath: IndexPath) {
        tableView.performBatchUpdates({ () -> Void in
            tableView.deleteRows(at: [indexPath], with: .right)
            tableView.insertRows(at: [destinationIndexPath], with: .right)
       }, completion: { [weak self] (finished) -> Void in
            self?.tableView.reloadData()
       })
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == .startFRE {
            let destinationNavigationController = segue.destination as! UINavigationController
            if let freViewController = destinationNavigationController.topViewController as? FrePageViewController {
                // passing userFreVersion and then setting current freVersion to userDefaults.
                freViewController.userFreVersion = SettingsConfig.lastFreVersionShown
                SettingsConfig.lastFreVersionShown = .freVersion
            }
        }
        
        if segue.identifier == .addCredentialSequeID {
            let destinationNavigationController = segue.destination as! UINavigationController
            if let addViewController = destinationNavigationController.topViewController as? AddCredentialController, let credential = credentailToAdd {
                    addViewController.displayCredential(details: credential)
                }
            credentailToAdd = nil
        }
    }
    
    @IBAction func unwindToMainViewController(segue: UIStoryboardSegue) {
        if let sourceViewController = segue.source as? AddCredentialController, let credential = sourceViewController.credential {
            // Add a new credential to table.
            viewModel.addCredential(credential: credential)
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
            
            guard let credential = YKFOATHCredential(url: url) else {
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
        if (YubiKitDeviceCapabilities.supportsMFIAccessoryKey && viewModel.keyPluggedIn) {
            viewModel.calculateAll()
        } else if (YubiKitDeviceCapabilities.supportsISO7816NFCTags) {
            activateNfc()
        }
        refreshControl?.endRefreshing()
    }
    
    //
    // MARK: - UI Setup
    //
    private func setupCredentialsSearchController() {
        credentialsSearchController = UISearchController(searchResultsController: nil)
        credentialsSearchController.searchResultsUpdater = self
        credentialsSearchController.obscuresBackgroundDuringPresentation = false
        credentialsSearchController.dimsBackgroundDuringPresentation = false
        credentialsSearchController.searchBar.placeholder = "Quick Find"
        navigationItem.searchController = credentialsSearchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
    }
    
    /*! Adds Yubico logo on the place of title
     */
    private func setupNavigationBar() {
        let titleView = UIView()
        titleView.frame = CGRect(x: 0, y: 0, width: navigationItem.titleView?.frame.width ?? 40, height: navigationItem.titleView?.frame.height ?? 40)
        
        let imageView = UIImageView()
        // image view within navigation bar needs some offsets/paddings from top and bottom
        // using custom view to fill full navitation bar view and adding padding in imageView frame
        imageView.frame = CGRect(x: 0, y: titleView.frame.height/4, width: titleView.frame.width, height: titleView.frame.height/2)
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "LogoText")
        titleView.addSubview(imageView)
        navigationItem.titleView = titleView
    }
    
    private func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        // setting background to refresh control changes behavior of spinner
        // and it gets dragged with pull rather than sticks to the top of the view
        refreshControl.backgroundColor = .clear
        refreshControl.addTarget(self, action:  #selector(refreshData), for: .valueChanged)
        self.refreshControl = refreshControl
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
        // using this background view to show on background when the table is empty
        // this background view contains 3 parts: image, title and optionally subtitle
        
        let width = self.view.bounds.size.width;
        let height = self.view.bounds.size.height
        
        let marginFromParent: CGFloat = 50.0
        let marginFromNeighbour: CGFloat = 20.0

        let backgroundView = UIView()
        backgroundView.center = tableView.center
        backgroundView.frame = CGRect(x: 0, y:0, width: width, height: height)
        
        
        // 1. image is in the middle of screen
        let imageView = UIImageView()
        imageView.frame = CGRect(x: 0, y: 0, width: width/2, height:124)
        imageView.contentMode = .scaleAspectFit
        if let image = getBackgroundImage() {
            imageView.image = image.withRenderingMode(.alwaysTemplate)
        }
        imageView.tintColor = UIColor.yubiBlue
        imageView.center = backgroundView.center
        backgroundView.addSubview(imageView)
        
        // 2. title is below the image
        let messageLabel = UILabel()
        messageLabel.frame =  CGRect(x: marginFromParent, y: 0, width: width - marginFromParent, height:height/4)
        messageLabel.textAlignment = NSTextAlignment.center
        messageLabel.text = getTitle()
        messageLabel.textColor = UIColor.secondaryText
        messageLabel.font = messageLabel.font.withSize(CGFloat(20.0))
        messageLabel.sizeToFit()

        messageLabel.center.y = imageView.frame.maxY + messageLabel.frame.height/2 + marginFromNeighbour
        messageLabel.center.x = backgroundView.center.x
        backgroundView.addSubview(messageLabel)

        // 3. subtitle (optional) is below the title
        if let subtitle = getSubtitle() {
            let secondaryMessageLabel = UILabel()
            // setting frame here because multiple lines label requires bounds,
            // otherwise it spreads outside of view boundaries in 1 line
            secondaryMessageLabel.frame =  CGRect(x: marginFromParent, y: 0, width: width - marginFromParent, height:height/4)
            secondaryMessageLabel.textAlignment = NSTextAlignment.center
            secondaryMessageLabel.numberOfLines = 3
            secondaryMessageLabel.text = subtitle
            secondaryMessageLabel.textColor = UIColor.secondaryText
            secondaryMessageLabel.sizeToFit()
            
            secondaryMessageLabel.center.y = messageLabel.frame.maxY + secondaryMessageLabel.frame.height/2 + marginFromNeighbour
            secondaryMessageLabel.center.x = backgroundView.center.x
            backgroundView.addSubview(secondaryMessageLabel)
        }
        
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(MainViewController.onBackgroundClick))
        backgroundView.isUserInteractionEnabled = true
        backgroundView.addGestureRecognizer(gestureRecognizer)

        self.tableView.backgroundView = backgroundView;
        self.tableView.separatorStyle = .none
    }
       
    private func getBackgroundImage() -> UIImage? {
        switch viewModel.state {
            case .loaded:
                // No accounts view
                return UIImage(named: "NoAccounts")
            default:
                // YubiKey image
                return UIImage(named: "InsertKey")
        }
    }
    
    private func getTitle() -> String {
        switch viewModel.state {
            case .idle:
                return viewModel.keyPluggedIn ? NSLocalizedString("Loading...", comment: "Main view title while the key plugged in and  loading data.") : NSLocalizedString("Insert your YubiKey", comment: "Main view title if the key not plugged in, asking to insert the key.")
            case .loading:
                return  NSLocalizedString("Loading...", comment: "Main view title while loading data.")
            case .locked:
                return NSLocalizedString("Authentication is required", comment: "Main view title when the key has password.")

            default:
                return viewModel.hasFilter ? NSLocalizedString("No accounts found", comment: "Main view title when filter is applied and has no results") : NSLocalizedString("Add accounts", comment: "Main view title when the key doesn't have any accounts.")
        }
    }
    
    private func getSubtitle() -> String? {
        switch viewModel.state {
            case .idle:
                return viewModel.keyPluggedIn || !YubiKitDeviceCapabilities.supportsISO7816NFCTags ? nil : NSLocalizedString("Pull down to refresh or activate NFC", comment: "Main view subtitle, instructions to activate NFC reader or to refresh table data.")
            case .loaded:
                return viewModel.hasFilter ? NSLocalizedString("No accounts matching your search criteria.", comment: "Main view subtitle when filter is applied and has no results.")
                    : NSLocalizedString("No accounts have been set up for this YubiKey. Tap + button to add an account.", comment: "Main view subtitle when the key doesn't have any accounts.")
            default:
                return nil
        }
    }
    
    @objc func onBackgroundClick() {
        switch viewModel.state {
            case .loaded:
                self.onAddCredentialClick(self)
            case .locked:
                let error = NSError(domain: "", code: Int(YKFKeyOATHErrorCode.authenticationRequired.rawValue), userInfo:nil)
                self.onError(error: error)
            default:
                break
        }
    }
}

//
// MARK: - Key Session Observer
//
extension  MainViewController: AccessorySessionObserverDelegate {
    
    func accessorySessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFAccessorySessionState) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshUIOnKeyStateUpdate()
        }
    }
}

extension  MainViewController: NfcSessionObserverDelegate {
    func nfcSessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFNFCISO7816SessionState) {
        guard #available(iOS 13.0, *) else {
            fatalError()
        }
        viewModel.nfcStateChanged(state: state)
        if state == .open {
            viewModel.calculateAll()
        }
    }
}
// MARK: ApplicationSessionObserverDelegate
extension MainViewController: ApplicationSessionObserverDelegate {
    func didEnterBackground() {
        viewModel.cleanUp()
    }
}

//
// MARK: - Search Results Extension
//

extension MainViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let filter = searchController.searchBar.text
        viewModel.applyFilter(filter: filter)
    }
}
    
