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

    private var keySessionObserver: KeySessionObserver!
    
    override func viewWillAppear(_ animated: Bool) {
        keySessionObserver = KeySessionObserver(nfcDlegate: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        keySessionObserver.observeSessionState = false
    }
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func savePassword(_ sender: Any) {
       if password.text != confirmPassword.text {
            self.showAlertDialog(title: "Error", message: "The passwords do not match")
        } else {
            viewModel.setCode(password: password.text ?? "")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // UITextViewDelegate added for switching resonder on return key on keyboard
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
            self.savePassword(self.saveButton as Any)
        default:
            break
        }
        return false
    }
}

extension  SetPasswordViewController: NfcSessionObserverDelegate {
    func nfcSessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFNFCISO7816SessionState) {
        viewModel.nfcStateChanged(state: state)
        if state == .open {
            viewModel.resume()
        }
    }
}

