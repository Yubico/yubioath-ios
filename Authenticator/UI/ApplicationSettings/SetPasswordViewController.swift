//
//  SetPasswordViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/31/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class SetPasswordViewController: UITableViewController {
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var confirmPassword: UITextField!

    private let viewModel = YubikitManagerModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        // register cell identifiers
        viewModel.delegate = self
        
    }
        
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func savePassword(_ sender: Any) {
        if(password.text != confirmPassword.text) {
            self.showAlertDialog(title: "Error", message: "The passwords do not match")
        } else {
            viewModel.setCode(password: password.text ?? "")
            // TODO: show progress bar
        }
    }
}

extension SetPasswordViewController : CredentialViewModelDelegate {
    func onError(operation: Operation, error: Error) {
        // TODO: hide progress
        self.showAlertDialog(title: "Error occured", message: error.localizedDescription)
    }
    
    func onOperationCompleted(operation: Operation) {
        // TODO: hide progress
        self.showAlertDialog(title: "Success", message: "The password has been successfully set") { [weak self] () -> Void in
            self?.dismiss(animated: true, completion: nil)
        }
    }
}
