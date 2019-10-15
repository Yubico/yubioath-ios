//
//  BaseOATHVIewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class BaseOATHVIewController: UITableViewController, CredentialViewModelDelegate {
    let viewModel = YubikitManagerModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // register cell identifiers
        viewModel.delegate = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // notify view model that view in foreground and it can resume operations
        viewModel.resume()
        
        // update view in case if state has changed
        self.tableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // prevent view model to work in background
        // we want to operate with key only in foreground
        viewModel.pause()
        super.viewWillDisappear(animated)
    }
    
//
// MARK: - CredentialViewModelDelegate
//
    func onError(operation: OperationName, error: Error) {
        let errorCode = (error as NSError).code;
        if (errorCode == YKFKeyOATHErrorCode.authenticationRequired.rawValue || errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue) {
            let message = errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue ? "Provided password was wrong" : "To prevent unauthorized access YubiKey is protected with a password"
            
            self.showPasswordPrompt(title: "Unlock YubiKey", message: message, inputHandler: {  [weak self] (password) -> Void in
                    self?.viewModel.validate(password: password)
                }, cancelHandler: {  [weak self] () -> Void in
                    self?.tableView.reloadData()
                })
        } else {
            self.showAlertDialog(title: "Error occured", message: error.localizedDescription)
        }
    }
    
    func onOperationCompleted(operation: OperationName) {
        switch operation {
        case .setCode:
            self.showAlertDialog(title: "Success", message: "The password has been successfully set") { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
            }
        case .reset:
            self.showAlertDialog(title: "Success", message: "The application has been successfully reset") { [weak self] () -> Void in
                self?.dismiss(animated: true, completion: nil)
                self?.tableView.reloadData()
            }
        default:
            break
        }
    }
    
    func onTouchRequired() {
        self.displayToast(message: "Touch your YubiKey")
    }    
}
