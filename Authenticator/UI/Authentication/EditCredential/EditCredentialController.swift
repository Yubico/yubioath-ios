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

class EditCredentialController: UITableViewController {
    public var credential: Credential?
    public var viewModel: OATHViewModel?
    public var model: CredentialViewModelDelegate?
    @IBOutlet weak var issuerRow: SettingsRowView!
    @IBOutlet weak var accountRow: SettingsRowView!
    
    override func viewDidLoad() {
        issuerRow.value = credential?.issuer
        accountRow.value = credential?.account
        super.viewDidLoad()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let settingsRow = (sender as? UITableViewCell)?.contentView.subviews.first as? SettingsRowView else { return }
        guard let editFieldController = segue.destination as? EditFieldController else { return }
        editFieldController.enablesReturnKeyAutomatically = settingsRow == accountRow
        editFieldController.settingsRow = settingsRow
    }
    
    @IBAction func save(_ sender: Any) {
        guard let credential = credential, let issuer = issuerRow.value, let account = accountRow.value, account.count > 0 else {
            showAlertDialog(title: "Account not set", message: "Account name can not be empty")
            return
        }
        
        viewModel?.renameCredential(credential: credential, issuer: issuer, account: account)
        self.dismiss(animated: true)
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true)
    }
}
