//
//  TokenRequestViewController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-25.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class TokenRequestViewController: UIViewController {
    var userInfo: [AnyHashable: Any]?
    
    @IBOutlet weak var accessoryLabel: UILabel!
    @IBOutlet weak var orLabel: UILabel!
    @IBOutlet weak var nfcLabel: UILabel!
    @IBOutlet weak var passwordTextField: UITextField!
    let viewModel = TokenRequestViewModel()
    var defaultAccessoryTest: String?
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        defaultAccessoryTest = accessoryLabel.text
    }
    
    @IBAction func submitPIN(_ sender: UITextField) {
        guard let userInfo = userInfo else { dismiss(animated: true, completion: nil); return }
        viewModel.handleTokenRequest(userInfo, password: sender.text!) { error in
            guard error == nil else { print("Error: \(error!)"); return }
            DispatchQueue.main.async {
                self.passwordTextField.resignFirstResponder()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        passwordTextField.becomeFirstResponder()
        viewModel.isAccessoryKeyConnected { [weak self] connected in
            print("connected: \(connected)")
            self?.orLabel.isHidden = connected
            self?.nfcLabel.isHidden = connected
            if connected {
                self?.accessoryLabel.text = "Enter PIN"
            } else {
                self?.accessoryLabel.text = self?.defaultAccessoryTest
            }
        }
    }
    
    @objc func didEnterBackground() {
        self.dismiss(animated: true, completion: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("Deinit TokenRequestViewController")
    }
    
}
