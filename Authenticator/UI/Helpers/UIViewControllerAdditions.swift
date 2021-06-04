//
//  UIViewControllerAdditions.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/31/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation
import LocalAuthentication

extension UIViewController {
    static let PasswordUserDefaultsKey = "PasswordSaveType"
 
    /*! Show error dialog to notify if some operation couldn't be executed
     */
    func showAlertDialog(title: String, message: String? = nil, nfcHandler: (() -> Void)? = nil, okHandler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let cancel = UIAlertAction(title: "OK", style: .cancel) { (action) -> Void in
                okHandler?()
            }
            
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags && nfcHandler != nil {
                let activate = UIAlertAction(title: "Activate NFC", style: .default) { (action) -> Void in
                    nfcHandler?()
                }
                alertController.addAction(activate)
            }
            alertController.addAction(cancel)
            self.present(alertController, animated: false)
        }
    }
    
    /*! Shows warning with option to cancel operation
     */
    func showWarning(title: String, message: String, okButtonTitle: String, style: UIAlertAction.Style = .destructive, okHandler: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let reset = UIAlertAction(title: okButtonTitle, style: style, handler: { (action) -> Void in
                okHandler?()
            })
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            alertController.addAction(reset)
            alertController.addAction(cancel)
            
            self.present(alertController, animated: false)
        }
    }
    
    /*! Shows small toast/text view on the bottom of screen to notify that something has happened (doesn't require user interaction)
     */
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
        toastView.textColor = UIColor.white
        toastView.backgroundColor = UIColor.yubiBlue
        toastView.center = CGPoint(x: keyWindow.center.x, y: keyWindow.bounds.height - toastView.bounds.height/2 - keyWindow.layoutMargins.bottom)
        DispatchQueue.main.async {
            keyWindow.addSubview(toastView)
            UIView.animate(withDuration: 5.0, animations: {
                toastView.alpha = 0.0
            }) { (finished) -> Void in
                toastView.removeFromSuperview()
            }
        }
    }

}