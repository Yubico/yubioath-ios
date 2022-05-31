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

class EditFieldController: UITableViewController, UINavigationControllerDelegate, UITextFieldDelegate {
    
    @IBOutlet weak var field: UITextField!
    var settingsRow: SettingsRowView?
    var enablesReturnKeyAutomatically: Bool = false
    
    override func viewWillAppear(_ animated: Bool) {
        field.text = settingsRow?.value
        title = settingsRow?.title
        field.becomeFirstResponder()
        field.delegate = self
        field.enablesReturnKeyAutomatically = enablesReturnKeyAutomatically;
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
