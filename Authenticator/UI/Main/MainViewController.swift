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
    private var keySessionObserver: KeySessionObserver!
    private var keyPluggedIn = YubiKitManager.shared.keySession.sessionState == .open;

    private var credentailToAdd: YKFOATHCredential?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupCredentialsSearchController()
        setupNavigationBar()
        
        if (!YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
            let error = KeySessionError.notSupported
            self.showAlertDialog(title: "", message: error.localizedDescription)
        }

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action:  #selector(refreshData), for: .valueChanged)
        self.refreshControl = refreshControl
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        keySessionObserver = KeySessionObserver(delegate: self)
        refreshUIOnKeyStateUpdate()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        keySessionObserver.observeSessionState = false
        super.viewWillDisappear(animated)
    }
    
    //
    // MARK: - Add cedential
    //
    @IBAction func onAddCredentialClick(_ sender: Any) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.view.tintColor = secondaryLabelColor
        if (YubiKitDeviceCapabilities.supportsQRCodeScanning) {
            // if QR codes are anavailable on device disable option
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
            actionSheet.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?[1]
        }
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    //
    // MARK: - Table view data source
    //
    override func numberOfSections(in tableView: UITableView) -> Int {
        if (viewModel.credentials.count > 0) {
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
        cell.updateView(credential: credential)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let credential = viewModel.credentials[indexPath.row]
            if (credential.type == .HOTP && credential.activeTime > 5) {
                // refresh HOTP on touch
                print("HOTP active for \(String(format:"%f", credential.activeTime)) seconds")
                viewModel.calculate(credential: credential)
            } else if (credential.code.isEmpty || credential.remainingTime <= 0) {
                // refresh items that require touch
                viewModel.calculate(credential: credential)
            } else {
                // copy to clipbboard
                UIPasteboard.general.string = credential.code
                self.displayToast(message: "Copied to clipboard!")
            }
        }
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            let credential = viewModel.credentials[indexPath.row]
            // show warning that user will delete credential to preven accident removals
            // we also won't update UI until
            // the actual removal happen (for example when user tapped key over NFC)
            showDeleteWarning(credential: credential)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
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
    
    //
    // MARK: - CredentialViewModelDelegate
    //
    override func onOperationCompleted(operation: OperationName) {
        switch operation {
        case .calculate:
            break
        case .filter:
            self.tableView.reloadData()
        default:
            // show search bar only if there are credentials on the key
            navigationItem.searchController = viewModel.credentials.count > 0 ? credentialsSearchController : nil
            self.tableView.reloadData()
        }
    }
    
    // MARK: - private methods
    
    private func scanQR() {
        YubiKitManager.shared.qrReaderSession.scanQrCode(withPresenter: self) {
            [weak self] (payload, error) in
            guard self != nil else {
                return
            }
            guard error == nil else {
                self?.onError(operation: .scan, error: error!)
                return
            }
            
            // This is an URL conforming to Key URI Format specs.
            guard let url = URL(string: payload!) else {
                self?.onError(operation: .scan, error: KeySessionError.invalidUri)
                return
            }
            
            guard let credential = YKFOATHCredential(url: url) else {
                self?.onError(operation: .scan, error: KeySessionError.invalidCredentialUri)
                return
            }
            
            self?.credentailToAdd = credential
            self?.performSegue(withIdentifier: .addCredentialSequeID, sender: self)
        }
    }

    private func refreshCredentials() {
        if (YubiKitDeviceCapabilities.supportsMFIAccessoryKey) {
            let sessionState = YubiKitManager.shared.keySession.sessionState
            print("Key session state: \(String(describing: sessionState.rawValue))")
            
            if (sessionState == YKFKeySessionState.open) {
                viewModel.calculateAll()
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
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey && YubiKitManager.shared.keySession.isKeyConnected {
            viewModel.calculateAll()
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

    private func refreshUIOnKeyStateUpdate() {
        #if DEBUG
            // allow to see add option on emulator
            navigationItem.rightBarButtonItem?.isEnabled = keyPluggedIn || !YubiKitDeviceCapabilities.supportsMFIAccessoryKey
        #else
            navigationItem.rightBarButtonItem?.isEnabled = keyPluggedIn
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
        
        // 1. title in the middle of screen
        let messageLabel = UILabel()
        messageLabel.frame =  CGRect(x: marginFromParent, y: 0, width: width - marginFromParent, height:height/4)
        messageLabel.textAlignment = NSTextAlignment.center
        messageLabel.text = getTitle()
        messageLabel.textColor = secondaryLabelColor
        messageLabel.font = messageLabel.font.withSize(CGFloat(25.0))
        messageLabel.sizeToFit()

        messageLabel.center = backgroundView.center
        backgroundView.addSubview(messageLabel)

        // 2. subtitle (optional) is below the title
        if let subtitle = getSubtitle() {
            let secondaryMessageLabel = UILabel()
            // setting frame here because multiple lines label requires bounds,
            // otherwise it spreads outside of view boundaries in 1 line
            secondaryMessageLabel.frame =  CGRect(x: marginFromParent, y: 0, width: width - marginFromParent, height:height/4)
            secondaryMessageLabel.textAlignment = NSTextAlignment.center
            secondaryMessageLabel.numberOfLines = 3
            secondaryMessageLabel.font = messageLabel.font.withSize(CGFloat(20.0))
            secondaryMessageLabel.text = subtitle
            secondaryMessageLabel.textColor = secondaryLabelColor
            secondaryMessageLabel.sizeToFit()
            
            secondaryMessageLabel.center.y = messageLabel.frame.maxY + secondaryMessageLabel.frame.height/2 + marginFromNeighbour
            secondaryMessageLabel.center.x = backgroundView.center.x
            backgroundView.addSubview(secondaryMessageLabel)
        }
        
        // 3. image is above the title (takes no more than 1/6 space of whole screen)
        let imageView = UIImageView()
        imageView.frame = CGRect(x: 0, y: 0, width: width/2, height:height/6)
        imageView.contentMode = .scaleAspectFit
        if let image = getBackgroundImage() {
            imageView.image = image.withRenderingMode(.alwaysTemplate)
        }
        if #available(iOS 13.0, *) {
            if self.traitCollection.userInterfaceStyle != .dark {
                // User Interface is Dark
                imageView.tintColor = UIColor(named: "YubiBlue")
            }
        } else {
            imageView.tintColor = UIColor(named: "YubiBlue")
        }
        imageView.center.y = messageLabel.frame.minY - marginFromNeighbour - imageView.frame.height/2
        imageView.center.x = backgroundView.center.x
        backgroundView.addSubview(imageView)
        
        self.tableView.backgroundView = backgroundView;
        self.tableView.separatorStyle = .none
    }
    
    private var secondaryLabelColor: UIColor {
        get {
            if #available(iOS 13.0, *) {
                return UIColor.secondaryLabel
            } else {
                return UIColor.systemGray
            }
        }
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
                return keyPluggedIn ? "Loading..." : "Insert YubiKey"
            case .loading:
                return  "Loading..."
            case .locked:
                return  "Authentication is required"
            default:
                return viewModel.hasFilter ? "No accounts found" :
                "Add accounts"
        }
    }
    
    private func getSubtitle() -> String? {
        switch viewModel.state {
            case .loaded:
                return viewModel.hasFilter ? "No accounts matching your search criteria." :
                "No accounts have been set up for this YubiKey. Tap + button to add an account."
            case .idle:
                return YubiKitManager.shared.keySession.isKeyConnected ? nil :
                "To read your accounts and codes generated for 2-step verification"
            default:
                return nil
        }
    }

    // MARK: - Custom warning for deletion of account

    private func showDeleteWarning(credential: Credential) {
        let name = !credential.issuer.isEmpty ? "\(credential.issuer) (\(credential.account))" : credential.account

        let alertController = UIAlertController(title: "Delete \(name)?", message: "This will permanently delete the credential from the YubiKey, and your ability to generate codes for it", preferredStyle: .alert)
        
        let reset = UIAlertAction(title: "Delete", style: .destructive, handler: { (action) -> Void in
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.deleteCredential(credential: credential)
            }
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in }
        alertController.addAction(reset)
        alertController.addAction(cancel)
        
        self.present(alertController, animated: false)
    }
}

extension String {
    fileprivate static let addCredentialSequeID = "AddCredentialSequeID"
}

//
// MARK: - Key Session Observer
//
extension  MainViewController: KeySessionObserverDelegate {
    
    func keySessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFKeySessionState) {
        self.keyPluggedIn = YubiKitManager.shared.keySession.sessionState == .open;
        refreshUIOnKeyStateUpdate()
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
    
