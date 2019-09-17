//
//  PasswordPromptController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/31/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UIViewController {
    
    func showPasswordPrompt(title: String, message: String, inputHandler: ((String) -> Void)? = nil, cancelHandler: (() -> Void)? = nil) {
        
        var inputTextField: UITextField?
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            // Do whatever you want with inputTextField?.text
            inputHandler?(inputTextField?.text ?? "")
        })
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) -> Void in
            cancelHandler?()
        }
        alertController.addTextField { (textField) -> Void in
            // Here you can configure the text field (eg: make it secure, add a placeholder, etc)
            inputTextField = textField
            inputTextField?.isSecureTextEntry = true
        }
        alertController.addAction(ok)
        alertController.addAction(cancel)
        
        self.present(alertController, animated: false)
    }

    func showAlertDialog(title: String, message: String, okHandler: (() -> Void)? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "OK", style: .cancel) { (action) -> Void in
            okHandler?()
        }
        alertController.addAction(cancel)
        self.present(alertController, animated: false)
    }
    
    func displayToast(message: String) {
        guard let keyWindow = UIApplication.shared.keyWindow else {
            return
        }
        
        // TODO: calculate width dynamically depending on message
        let toastView = UILabel(frame: CGRect(x: 0, y: 0, width: keyWindow.frame.size.width*3.0/4.0, height: 50.0))
        toastView.text = message;
        toastView.numberOfLines = 0
        toastView.lineBreakMode = .byWordWrapping
        toastView.textAlignment = .center;
        toastView.layer.cornerRadius = 10;
        toastView.layer.masksToBounds = true;
        toastView.backgroundColor = UIColor.lightGray
        toastView.center = CGPoint(x: keyWindow.center.x, y: keyWindow.bounds.height - toastView.bounds.height/2 - keyWindow.layoutMargins.bottom)
        
        keyWindow.addSubview(toastView)
        UIView.animate(withDuration: 5.0, animations: {
            toastView.alpha = 0.0
        }) { (finished) -> Void in
            toastView.removeFromSuperview()
        }
    }

}
