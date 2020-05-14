//
//  EditCredentialController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2020-05-07.
//  Copyright © 2020 Yubico. All rights reserved.
//

import UIKit

class EditCredentialController: UITableViewController {
    public var credential: Credential?
    public var viewModel: YubikitManagerModel?
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
        editFieldController.settingsRow = settingsRow
    }
    
    @IBAction func save(_ sender: Any) {
        guard let credential = credential, let issuer = issuerRow.value, let account = accountRow.value, account.count > 0 else {
            showAlertDialog(title: "Account not set")
            return
        }
        
        viewModel?.renameCredential(credential: credential, issuer: issuer, account: account)
        self.dismiss(animated: true)
    }
    
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true)
    }
}
