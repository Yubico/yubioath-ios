//
//  EditFieldController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2020-05-07.
//  Copyright © 2020 Yubico. All rights reserved.
//

import UIKit

class EditFieldController: UITableViewController, UINavigationControllerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var field: UITextField!
    var settingsRow: SettingsRowView?
    
    override func viewWillAppear(_ animated: Bool) {
        field.text = settingsRow?.value
        title = settingsRow?.title
        field.becomeFirstResponder()
        field.delegate = self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        settingsRow?.value = field.text
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        navigationController?.popViewController(animated: true)
        return true
    }
}
