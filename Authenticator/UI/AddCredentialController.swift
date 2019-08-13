//
//  AddCredentialController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class AddCredentialController: UITableViewController {

    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var addScannedButton: UIButton!
    @IBOutlet weak var issuerScannedText: UITextField!
    @IBOutlet weak var accountScannedText: UITextField!
    @IBOutlet weak var addManualButton: UIButton!
    @IBOutlet weak var issuerManualText: UITextField!
    @IBOutlet weak var accountManualText: UITextField!
    @IBOutlet weak var secretManualText: UITextField!
    @IBOutlet weak var secretValidationLabel: UILabel!
    @IBOutlet var allManualTextFields: [UITextField]!
    var advancedSettingsPicker: UIPickerView! = UIPickerView()
    @IBOutlet weak var periodManualText: UITextField!
    @IBOutlet weak var advancedSettingsButton: UIButton!
    @IBOutlet weak var typeManualText: UITextField!
    @IBOutlet weak var algorithmManualText: UITextField!
    @IBOutlet weak var digitsManualText: UITextField!
    
    private var url: URL?
    private var manualEntryExpanded: Bool = false

    var advancedSettings: [[String]] = [["TOTP", "HOTP"],
                                  ["SHA1", "SHA256", "SHA512",],
                                  ["6", "7", "8"]]
    /*
     This value is either passed by `MainViewController` in `prepare(for:sender:)`
     or constructed as part of scanning/manual input operation.
     */
    var credential: YKFOATHCredential?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // if QR codes are anavailable on device disable button
        scanButton.isEnabled = YubiKitDeviceCapabilities.supportsQRCodeScanning
        
        // For removing the extra empty spaces of TableView below
        tableView.tableFooterView = UIView()
        
        setupAddManualView()
        
    }
    
    // MARK: - Table view cell sizes
/*
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 0 {
            manualEntryExpanded = !manualEntryExpanded
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }
  */
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            if (url == nil) {
                // first cell collapsed 140
                return 160
            } else {
                return 340
            }
        }
        if indexPath.section == 1 && indexPath.row == 0 {
            if manualEntryExpanded {
                return 700
            } else {
                return 350
            }
        }
        return 80
    }
    
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func advanceSettingsPressed(_ sender: Any) {
        manualEntryExpanded = !manualEntryExpanded
        advancedSettingsButton.setTitle(manualEntryExpanded ? "Hide advanced settings" : "Advanced Settings", for: .normal)
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    @IBAction func scanQRCodeButtonPressed(_ sender: Any) {
        YubiKitManager.shared.qrReaderSession.scanQrCode(withPresenter: self) {
            [weak self] (payload, error) in
            guard self != nil else {
                return
            }
            guard error == nil else {
                // TODO: handle error
                return
            }
            
            // This is an URL conforming to Key URI Format specs.
            guard let url = URL(string: payload!) else {
                fatalError()
            }
            
            guard let credential = YKFOATHCredential(url: url) else {
                print("Invalid URI format")
                return
            }

            self?.issuerScannedText.text = credential.issuer
            self?.accountScannedText.text = credential.account
            self?.url = url
            self?.tableView.beginUpdates()
            self?.tableView.endUpdates()
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        if let button = sender as? UIButton, button == addScannedButton, self.url != nil {
            // Create the credential from the URL using the convenience initializer.
            guard let credential = YKFOATHCredential(url: self.url!) else {
                // TODO: notify with error alert
                print("Invalid URI format")
                return
            }
            
            // Set the credential to be passed to MainViewController after the unwind segue.
            credential.issuer = self.issuerScannedText.text ?? ""
            credential.account = self.accountScannedText.text ?? ""
            
            self.credential = credential
        } else if let button = sender as? UIButton, button == addManualButton {
            // Create the credential from manual input
            let credential = YKFOATHCredential()
            
            // Set the credential to be passed to MainViewController after the unwind segue.
            credential.issuer = self.issuerManualText.text ?? ""
            credential.account = self.accountManualText.text ?? ""
            
            // use the base32DecodeData (of type Data) and set it on the credential:
            guard let base32DecodedSecret = NSData.ykf_data(withBase32String: self.secretManualText.text ?? "") else {
                // we already validated input before enabling action button, so this should never happen
                // TODO: but better to notify with error alert
                print("Invalid Base32 encoded string")
                return
            }
            credential.secret = base32DecodedSecret

            if (manualEntryExpanded) {
                credential.period = UInt(periodManualText.text ?? "30") ?? 30
                credential.type = YKFOATHCredentialType.init(rawValue: UInt(advancedSettingsPicker.selectedRow(inComponent: 0) + 1)) ?? .TOTP
                credential.algorithm = YKFOATHCredentialAlgorithm.init(rawValue: UInt(advancedSettingsPicker.selectedRow(inComponent: 1) + 1)) ?? .SHA1
                credential.digits = UInt(advancedSettingsPicker.selectedRow(inComponent: 2) + 6)
            }
        
            self.credential = credential
        } else {
            print("The save button was not pressed, cancelling")
        }
    }
    
    // MARK: - Helper Methods
    
    fileprivate func setupAddManualView() {
        // configure each edit text for validation
        issuerManualText.delegate = self
        accountManualText.delegate = self
        secretManualText.delegate = self
        
        // configure error validation Label
        secretValidationLabel.isHidden = true
        
        // configure pickers for advanced settings
        advancedSettingsPicker.delegate = self
        advancedSettingsPicker.dataSource = self
        
        typeManualText.delegate = self
        typeManualText.inputView = advancedSettingsPicker
        algorithmManualText.delegate = self
        algorithmManualText.inputView = advancedSettingsPicker
        digitsManualText.delegate = self
        digitsManualText.inputView = advancedSettingsPicker

        addManualButton.isEnabled = false
        
        // Register View Controller as Observer
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange(_:)), name: UITextField.textDidChangeNotification, object: nil)
    }
    
    fileprivate func validate(_ textField: UITextField) -> (Bool, String?) {
        guard let text = textField.text else {
            return (false, nil)
        }
        
        if textField == secretManualText {
            let base32DecodedSecret = NSData.ykf_data(withBase32String: self.secretManualText.text ?? "")
            return (base32DecodedSecret != nil, "Invalid Base32 encoded string")
        }
        
        return (text.count > 0, "All fields are required and cannot be empty.")
    }
    
    // MARK: - Notification Handling (text change)
    
    @objc private func textDidChange(_ notification: Notification) {
        var formIsValid = true
        
        for textField in allManualTextFields {
            // Validate Text Field
            let (valid, _) = validate(textField)
            
            guard valid else {
                formIsValid = false
                break
            }
        }
        
        // Update Add Button
        addManualButton.isEnabled = formIsValid
    }
}

// MARK: - UITextFieldDelegate
extension AddCredentialController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Validate Text Field
        let (valid, message) = validate(textField)

        // Update error validation Label
        self.secretValidationLabel.text = message
        
        // Show/Hide Password Validation Label
        UIView.animate(withDuration: 0.25, animations: {
            self.secretValidationLabel.isHidden = valid
        })
        
        switch textField {
        case issuerManualText:
            if valid {
                accountManualText.becomeFirstResponder()
            }
        case accountManualText:
            if valid {
                secretManualText.becomeFirstResponder()
            }
        case secretManualText:
            if valid {
                secretManualText.resignFirstResponder()
            }
        default:
            textField.resignFirstResponder()
        }
        
        return true
    }
}

// MARK: - UIPickerViewDelegate
extension AddCredentialController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return advancedSettings.count
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return advancedSettings[component].count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return advancedSettings[component][row]
    }
    
    // Capture the picker view selection
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // This method is triggered whenever the user makes a change to the picker selection.
        // The parameter named row and component represents what was selected.
        switch(component) {
        case  0:
                // if HOTP selected we don't show period option
                periodManualText.isEnabled = row == 0
                typeManualText.text = advancedSettings[component][row]
        case 1:
            algorithmManualText.text = advancedSettings[component][row]
        case 2:
            digitsManualText.text = advancedSettings[component][row]
        default:
            print("Unexpected selection")
        }
            
    }
}
