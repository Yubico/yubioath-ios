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

class SetPasswordViewController: UITableViewController {
    
    let viewModel = PasswordConfigurationViewModel()

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var confirmPassword: UITextField!

    @IBAction func passwordChanged(_ sender: UITextField) {
        validatePasswords()
    }
    
    @IBAction func confirmPasswordChanged(_ sender: UITextField) {
        validatePasswords()
    }
    
    func validatePasswords() {
        saveButton.isEnabled = password.hasText && confirmPassword.hasText && password.text == confirmPassword.text
    }
    
    @IBAction func  cancel(_ sender: UIButton) {
        dismiss()
    }
    
    func dismiss() {
        performSegue(withIdentifier: "unwindToParent", sender: self)
    }
    
    @IBAction func savePassword(_ sender: Any) {
        if !password.hasText && !confirmPassword.hasText {
            self.showAlertDialog(title: String(localized: "Error"), message: String(localized: "Password can not be an empty string", comment: "Configuration set password empty password error alert message"))
        } else if password.text != confirmPassword.text {
            self.showAlertDialog(title: String(localized: "Error"), message: String(localized: "The passwords do not match", comment: "Configuration set password not matching error alert message"))
        } else {
            self.changePassword(password: password.text ?? "", oldPassword: nil)
        }
    }
    
    func changePassword(password: String, oldPassword: String?) {
        viewModel.changePassword(password: password, oldPassword: oldPassword) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    if let message = message {
                        let alert = UIAlertController(title: message) {
                            self.dismiss()
                        }
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        self.dismiss()
                    }
                case .authenticationRequired:
                    let authenticationAlert = UIAlertController(passwordEntryType: .password) { oldPassword in
                        guard let oldPassword = oldPassword else {
                            self.dismiss()
                            return
                        }
                        self.changePassword(password: password, oldPassword: oldPassword)
                    }
                    self.present(authenticationAlert, animated: true, completion: nil)
                case .wrongPassword:
                    let authenticationAlert = UIAlertController(passwordEntryType: .retryPassword) { oldPassword in
                        guard let oldPassword = oldPassword else {
                            self.dismiss()
                            return
                        }
                        self.changePassword(password: password, oldPassword: oldPassword)
                    }
                    self.present(authenticationAlert, animated: true, completion: nil)
                case .failure(let errorMessage):
                    if let message = errorMessage {
                        let alert = UIAlertController(title: message) {
                            self.dismiss()
                        }
                        self.present(alert, animated: true, completion: nil)
                    } else {
                        self.dismiss()
                    }
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // UITextViewDelegate added for switching responder on return key on keyboard
        self.password.delegate = self
        self.confirmPassword.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.password.becomeFirstResponder()
    }
    
    deinit {
        print("deinit SetPasswordViewController")
    }
}

extension SetPasswordViewController: UITextFieldDelegate {
        
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case password:
            confirmPassword.becomeFirstResponder()
        case confirmPassword:
            confirmPassword.resignFirstResponder()
            self.savePassword(self.saveButton as Any)
        default:
            break
        }
        return false
    }
}
