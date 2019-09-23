//
//  BaseOATHVIewControllerTableViewController.swift
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
        // TODO: add pull to refresh feaute so that in case of some error user can retry to read all (no need to unplug and plug)
        let errorCode = (error as NSError).code;
        if (errorCode == YKFKeyOATHErrorCode.authenticationRequired.rawValue || errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue) {
            let message = errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue ? "Provided password was wrong" : "To prevent anauthorized access YubiKey is protected with a password"
            
            self.showPasswordPrompt(title: "Unlock YubiKey", message: message, inputHandler: {  [weak self] (password) -> Void in
                    self?.viewModel.validate(password: password)
                }, cancelHandler: {  [weak self] () -> Void in
                    self?.tableView.reloadData()
                })
        } else {           
            // TODO: think about better error dialog for case when no connection (future NFC support - ask to tap over NFC)
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
