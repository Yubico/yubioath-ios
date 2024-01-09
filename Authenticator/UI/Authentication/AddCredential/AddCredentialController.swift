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

class AddCredentialController: UITableViewController {
    
    var accountSubject: PassthroughSubject<(YKFOATHCredentialTemplate?, Bool), Never>?
    
    enum EntryMode {
        case manual, prefilled
    }
    
    public var mode: EntryMode = .prefilled {
        didSet {
            self.tableView.reloadData()
        }
    }

    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var issuerManualText: UITextField!
    @IBOutlet weak var accountManualText: UITextField!
    @IBOutlet weak var secretManualText: UITextField!
    @IBOutlet weak var requiresTouchSwitch: UISwitch!
    @IBOutlet weak var periodManualText: UILabel!

    var advancedSettings: [[String]] = [["TOTP", "HOTP"],
                                        ["SHA1", "SHA256", "SHA512",],
                                        ["6", "8"],
                                        ["15", "30", "60"]]
    /*
     This value is either passed by `MainViewController` in `prepare(for:sender:)`
     or constructed as part of scanning/manual input operation.
     */
    var credential: YKFOATHCredentialTemplate? {
        didSet {
            updateWith(credential: credential)
        }
    }
    
    private func updateWith(credential: YKFOATHCredentialTemplate?) {
        if let credential, let issuerManualText, let accountManualText {
            issuerManualText.text = credential.issuer
            accountManualText.text = credential.accountName
            accountManualText.returnKeyType = mode == .manual ? .next : .done
        }
    }
        
    var requiresTouch: Bool = false
    var scanAccountView: ScanAccountView?

    var typeIndex = 0
    var algorithmIndex = 0
    var digitsIndex = 0
    var periodIndex = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // UITextViewDelegate added for switching responder on return key on keyboard
        self.issuerManualText.delegate = self
        self.accountManualText.delegate = self
        self.secretManualText.delegate = self
        self.accessibilityViewIsModal = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Always start QR scanner if no credential template was provided
        if self.credential == nil && self.mode != .manual {
            let scanAccountView = ScanAccountView(frame: self.view.frame) { [weak self] result in
                guard let self = self else { return }
                self.navigationController?.navigationBar.layer.zPosition = 0
                switch result {
                case .cancel:
                    self.dismiss(animated: true)
                case .manuelEntry:
                    self.mode = .manual
                case .account(let account):
                    self.credential = account
                    self.mode = .prefilled
                    self.updateWith(credential: account)
                }
            }
            self.scanAccountView = scanAccountView
            self.navigationController?.view.addSubview(scanAccountView)
            scanAccountView.autoresizingMask = .flexibleHeight
            self.navigationController?.navigationBar.layer.zPosition = -1 // Move buttons behind scanview
        } else {
            updateWith(credential: credential)
        }
        self.tableView.reloadData()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        scanAccountView?.viewWillTransition(to: size, with: coordinator)
        super.viewWillTransition(to: size, with: coordinator)
     }
        
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        accountSubject?.send((nil, true))
    }
    
    // MARK: - Button handlers
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func save(_ sender: Any) {
        do {
            switch mode {
            case .manual:
                let secret = NSData.ykf_data(withBase32String: self.secretManualText.text?.replacingOccurrences(of: " ", with: "") ?? "") ?? Data()
                let credentialType = YKFOATHCredentialType.typeFromString(advancedSettings[0][typeIndex])
                let algorithm = YKFOATHCredentialAlgorithm.algorithmFromString(advancedSettings[1][algorithmIndex])
                
                self.credential = try YKFOATHCredentialTemplate(type: credentialType,
                                                                algorithm: algorithm,
                                                                secret: secret,
                                                                issuer: self.issuerManualText.text ?? "",
                                                                accountName: self.accountManualText.text ?? "",
                                                                digits: UInt(advancedSettings[2][digitsIndex]) ?? 6,
                                                                period: UInt(advancedSettings[3][periodIndex]) ?? 30,
                                                                counter: 0,
                                                                skip: [])
            case .prefilled:
                guard let credential = credential else { return }
                self.credential = try YKFOATHCredentialTemplate(type: credential.type,
                                                                algorithm: credential.algorithm,
                                                                secret: credential.secret,
                                                                issuer: self.issuerManualText.text ?? "",
                                                                accountName: self.accountManualText.text ?? "",
                                                                digits: credential.digits,
                                                                period: credential.period,
                                                                counter: credential.counter,
                                                                skip: [])
            }
        } catch {
            showAlertDialog(title: "Not valid credential information", message: error.localizedDescription)
            return
        }
        self.requiresTouch = requiresTouchSwitch.isOn
        self.accountSubject?.send((credential!, requiresTouchSwitch.isOn))
        self.dismiss(animated: true)
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
            return typeIndex == 0 ? 44.0 : 0.0
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
            switch(indexPath.row) {
            case 0:
                cell.detailTextLabel?.text = advancedSettings[0][typeIndex]
            case 1:
                cell.detailTextLabel?.text = advancedSettings[1][algorithmIndex]
            case 2:
                cell.detailTextLabel?.text = advancedSettings[2][digitsIndex]
            default:
                cell.detailTextLabel?.text = advancedSettings[3][periodIndex]
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        switch indexPath.row {
        case 0:
            let table = AdvancedSettingsViewController(title: "Type",
                                                       rows: advancedSettings[0],
                                                       selected: typeIndex) { [weak self] result in
                self?.typeIndex = result
            }
            self.navigationController?.pushViewController(table, animated: true)
        case 1:
            let table = AdvancedSettingsViewController(title: "Algorithm",
                                                       rows: advancedSettings[1],
                                                       selected: algorithmIndex) { [weak self] result in
                self?.algorithmIndex = result
            }
            self.navigationController?.pushViewController(table, animated: true)
        case 2:
            let table = AdvancedSettingsViewController(title: "Digits",
                                                       rows: advancedSettings[2],
                                                       selected: digitsIndex) { [weak self] result in
                self?.digitsIndex = result
            }
            self.navigationController?.pushViewController(table, animated: true)
        case 3:
            let table = AdvancedSettingsViewController(title: "Period",
                                                       rows: advancedSettings[3],
                                                       selected: periodIndex) { [weak self] result in
                self?.periodIndex = result
            }
            self.navigationController?.pushViewController(table, animated: true)
         default:
            return
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

extension YKFOATHCredentialType {
    static func typeFromString(_ string: String) -> YKFOATHCredentialType {
        switch string {
        case "TOTP":
            return .TOTP
        case "HOTP":
            return .HOTP
        default:
            return .unknown
        }
    }
}

extension YKFOATHCredentialAlgorithm {
    
    static func algorithmFromString(_ string: String) -> YKFOATHCredentialAlgorithm {
        switch string {
        case "SHA1":
            return .SHA1
        case "SHA256":
            return .SHA256
        case "SHA512":
            return .SHA512
        default:
            return .unknown
        }
    }
}
