//
//  SetPasswordViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/31/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

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
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func savePassword(_ sender: Any) {
        if !password.hasText && !confirmPassword.hasText {
            self.showAlertDialog(title: "Error", message: "Password can not be an empty string")
        } else if password.text != confirmPassword.text {
            self.showAlertDialog(title: "Error", message: "The passwords do not match")
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
