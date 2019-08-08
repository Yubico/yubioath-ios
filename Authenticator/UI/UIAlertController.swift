//
//  UIAlertController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/5/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UIAlertController {
    
    static func setPassword(title: String, message: String, inputHandler: ((String) -> Void)? = nil) -> UIAlertController {
        var inputTextField: UITextField?
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            // Do whatever you want with inputTextField?.text
            inputHandler?(inputTextField!.text!)
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in }
        alertController.addTextField { (textField) -> Void in
            // Here you can configure the text field (eg: make it secure, add a placeholder, etc)
            inputTextField = textField
        }
        alertController.addAction(ok)
        alertController.addAction(cancel)

        return alertController
    }
    
    static func errorDialog(title: String, message: String) -> UIAlertController {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "OK", style: .cancel) { (action) -> Void in }
        alertController.addAction(cancel)
        return alertController
    }

}
