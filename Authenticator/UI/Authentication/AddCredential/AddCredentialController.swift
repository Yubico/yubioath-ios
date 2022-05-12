//
//  AddCredentialController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class AddCredentialController: UITableViewController {
    
    enum EntryMode {
        case manual, scanQR
    }
    
    public var mode: EntryMode = .scanQR {
        didSet {
            issuerManualText.text = credential?.issuer ?? ""
            accountManualText.text = credential?.accountName ?? ""
            accountManualText.returnKeyType = mode == .manual ? .next : .done
            self.tableView.reloadData()
        }
    }

    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var issuerManualText: UITextField!
    @IBOutlet weak var accountManualText: UITextField!
    @IBOutlet weak var secretManualText: UITextField!
    @IBOutlet weak var requireTouchManual: UISwitch!
    @IBOutlet var allManualTextFields: [UITextField]!
    @IBOutlet weak var periodManualText: UILabel!

    var advancedSettings: [[String]] = [["TOTP", "HOTP"],
                                        ["SHA1", "SHA256", "SHA512",],
                                        ["6", "7", "8"],
                                        ["15", "30", "60"]]
    /*
     This value is either passed by `MainViewController` in `prepare(for:sender:)`
     or constructed as part of scanning/manual input operation.
     */
    var credential: YKFOATHCredentialTemplate?
    var requiresTouch: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // UITextViewDelegate added for switching resonder on return key on keyboard
        self.issuerManualText.delegate = self
        self.accountManualText.delegate = self
        self.secretManualText.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if mode == .scanQR {
            let scanView = ScanAccountView(frame: self.view.frame) { [weak self] result in
                guard let self = self else { return }
                self.navigationController?.navigationBar.layer.zPosition = 0
                switch result {
                case .cancel:
                    self.dismiss(animated: true)
                case .manuelEntry:
                    self.mode = .manual
                case .account(let account):
                    self.credential = account
                    self.mode = .scanQR
                }
            }
            self.navigationController?.view.addSubview(scanView)
            self.navigationController?.navigationBar.layer.zPosition = -1 // Move buttons behind scanview
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.tableView.reloadData()
    }
    
    // MARK: - Public methods
    
    func displayCredential(details: YKFOATHCredentialTemplate) {
        credential = details
    }
    
    //
    // MARK: - Button handlers
    //
    
    @IBAction func cancel(_ sender: Any) {
        // reset all advanced settings to default
        resetDefaults()

        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func save(_ sender: Any) {
        let (valid, message) = validate()
        if !valid {
            showAlertDialog(title: "Not valid credential information", message: message ?? "")
        } else {
            self.performSegue(withIdentifier: .unwindToMainViewController, sender: sender)
        }
    }
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        if let button = sender as? UIBarButtonItem, button == saveButton {
            // Set the credential to be passed to MainViewController after the unwind segue.
            if let credential = self.credential {
                // Credential is populated from QR code, apply user changes
                self.credential = YKFOATHCredentialTemplate(type: credential.type,
                                                            algorithm: credential.algorithm,
                                                            secret: credential.secret,
                                                            issuer: self.issuerManualText.text ?? "",
                                                            accountName: self.accountManualText.text ?? "",
                                                            digits: credential.digits,
                                                            period: credential.period,
                                                            counter: credential.counter)
                self.requiresTouch = self.requireTouchManual.isOn
            } else {
                // Create the credential from manual input
                let type: YKFOATHCredentialType = getSelectedIndex(row: 0) == 0 ? .TOTP : .HOTP
                let algorithm = YKFOATHCredentialAlgorithm.init(rawValue: UInt(getSelectedIndex(row: 1) + 1)) ?? .SHA1
                let secret = NSData.ykf_data(withBase32String: self.secretManualText.text ?? "") ?? Data()
                self.credential = YKFOATHCredentialTemplate(type: type,
                                                            algorithm: algorithm,
                                                            secret: secret,
                                                            issuer: self.issuerManualText.text ?? "",
                                                            accountName: self.accountManualText.text ?? "",
                                                            digits: UInt(getSelectedIndex(row: 2) + 6),
                                                            period: UInt(periodManualText.text ?? "30") ?? 0,
                                                            counter: 0)

                // reset all advanced settings to default
                resetDefaults()
            }
        } else {
            print("The save button was not pressed, cancelling")
        }
    }
    
    // MARK: - Table view cell sizes
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let height = super.tableView(tableView, heightForRowAt: indexPath)
        
        // hide secret field from scanned mode
        if (indexPath.section == 0 && indexPath.row == 2) {
            return mode == .manual ? 44.0 : 0.0
        }
        
        // hide period for HOTP
        if (indexPath.section == 1 && indexPath.row == 3) {
            return getSelectedIndex(row: 0) == 0 ? 44.0 : 0.0
        }
        
        return height
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let title = super.tableView(tableView, titleForHeaderInSection: section)
        return (mode == .manual || section == 0) ? title : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let title = super.tableView(tableView, titleForFooterInSection: section)
        return (mode == .manual || section == 0) ? title : nil
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = super.tableView(tableView, numberOfRowsInSection: section)
        return (mode == .manual || section == 0) ? count : 0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return (mode == .manual || section == 0) ? UITableView.automaticDimension : CGFloat.leastNonzeroMagnitude
    }
    
    // MARK: - Table view content
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if ("AdvancedSettings" == cell.reuseIdentifier) {
            let selectedIndex = getSelectedIndex(row: indexPath.row)
            cell.detailTextLabel?.text = advancedSettings[indexPath.row][selectedIndex]
        }
        return cell
    }
    
    //
    // MARK: - Helper Methods
    //
    fileprivate func getSelectedIndex(row: Int) -> Int {
        let controller: AdvancedSettingsViewController
        switch(row) {
        case 0:
            controller = TypeTableViewController()
        case 1:
            controller = AlgorithmTableViewController()
        case 2:
            controller = DigitsTableViewController()
        default:
            controller = PeriodTableViewController()
        }
        return controller.selectedRow
    }
    
    fileprivate func validate() -> (Bool, String?) {
        let textFields:[UITextField] = mode == .manual ? allManualTextFields : [accountManualText]
        var formIsValid = true
        var formMessage: String? = nil
        for textField in textFields {
            // Validate Text Field
            let (valid, message) = validate(textField)

            guard valid else {
                formIsValid = false
                formMessage = message
                break
            }
        }
        
        return (formIsValid, formMessage)
    }
    
    fileprivate func validate(_ textField: UITextField) -> (Bool, String?) {
        guard let text = textField.text else {
            return (false, nil)
        }
        
        if textField == secretManualText && text.count > 0 {
            let base32DecodedSecret = NSData.ykf_data(withBase32String: text)
            return (base32DecodedSecret != nil, "Invalid Base32 encoded string. For secret use symbols A-Z and numbers 2-7.")
        }
        
        return (text.count > 0, "Required fields cannot be empty.")
    }
    
    fileprivate func resetDefaults() {
        let defaults = UserDefaults.standard
        AdvancedSettingsViewController.ALL_KEYS.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }
}

//
// MARK: - UITextFieldDelegate
//

extension AddCredentialController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case issuerManualText:
            accountManualText.becomeFirstResponder()
        case accountManualText:
            if mode == .manual {
                secretManualText.becomeFirstResponder()
            } else {
                accountManualText.resignFirstResponder()
            }
        case secretManualText:
            secretManualText.resignFirstResponder()
        default:
            textField.resignFirstResponder()
        }
        return false
    }
}
