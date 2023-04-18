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

class AddCredentialController: UITableViewController {
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // UITextViewDelegate added for switching resonder on return key on keyboard
        self.issuerManualText.delegate = self
        self.accountManualText.delegate = self
        self.secretManualText.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Always start QR scanner if no credential template was provided
        if self.credential == nil {
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
                    self.mode = .prefilled
                    updateWith(credential: account)
                }
            }
            self.navigationController?.view.addSubview(scanView)
            self.navigationController?.navigationBar.layer.zPosition = -1 // Move buttons behind scanview
        } else {
            updateWith(credential: credential)
        }
    }
    
    // MARK: - Button handlers
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func save(_ sender: Any) {
        do {
            switch mode {
            case .manual:
                let type: YKFOATHCredentialType = getSelectedIndex(row: 0) == 0 ? .TOTP : .HOTP
                let algorithm = YKFOATHCredentialAlgorithm.init(rawValue: UInt(getSelectedIndex(row: 1) + 1)) ?? .SHA1
                let secret = NSData.ykf_data(withBase32String: self.secretManualText.text ?? "") ?? Data()
                self.credential = try YKFOATHCredentialTemplate(type: type,
                                                                algorithm: algorithm,
                                                                secret: secret,
                                                                issuer: self.issuerManualText.text ?? "",
                                                                accountName: self.accountManualText.text ?? "",
                                                                digits: UInt(getSelectedIndex(row: 2) + 6),
                                                                period: UInt(periodManualText.text ?? "30") ?? 0,
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
        self.performSegue(withIdentifier: .unwindToMainViewController, sender: sender)
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
