//
//  SetPasswordViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/31/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class SetPasswordViewController: BaseOATHVIewController {
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var confirmPassword: UITextField!
        
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func savePassword(_ sender: Any) {
        if(password.text != confirmPassword.text) {
            self.showAlertDialog(title: "Error", message: "The passwords do not match")
        } else {
            viewModel.setCode(password: password.text ?? "")
        }
    }
    
    override func viewDidLoad() {
        self.password.delegate = self
        self.confirmPassword.delegate = self
    }
}

extension SetPasswordViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case password:
            confirmPassword.becomeFirstResponder()
        case confirmPassword:
            confirmPassword.resignFirstResponder()
        default:
            break
        }
        return false
    }
}
