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
    var viewModel: TokenRequestViewModel?
    var defaultAccessoryTest: String?
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var arrowHintView: UIView!
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        defaultAccessoryTest = accessoryLabel.text
        overlayView.alpha = 0
        arrowHintView.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel = TokenRequestViewModel()
        passwordTextField.becomeFirstResponder()
        viewModel?.isAccessoryKeyConnected { [weak self] connected in
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
    
    @IBAction func cancel(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func submitPIN(_ sender: UITextField) {
        guard let userInfo = userInfo else { dismiss(animated: true, completion: nil); return }
        viewModel?.handleTokenRequest(userInfo, password: sender.text!) { error in
            guard error == nil else {
                DispatchQueue.main.async {
                    self.passwordTextField.text = nil
                    switch error! {
                    case .alreadyHandled:
                        return
                    default:
                        let alert = UIAlertController(title: error?.message.title, message: error?.message.text) { }
                        self.present(alert, animated: true, completion: nil)
                    }
                }
                return
            }
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.5) {
                    self.overlayView.alpha = 1
                }
                self.animateHint()
                self.passwordTextField.resignFirstResponder()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("Deinit TokenRequestViewController")
    }
    
}

@available(iOS 14.0, *)
extension TokenRequestViewController {
    
    func animateHint() {
        UIView.animateKeyframes(withDuration: 3, delay: 0.5, options: .calculationModeCubicPaced) {
            
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1.0/3.0) {
                self.arrowHintView.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 1.0/3.0, relativeDuration: 1.0/3.0) {
                self.arrowHintView.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 2.0/3.0, relativeDuration: 1.0/3.0) {
                self.arrowHintView.alpha = 1
            }
        }
    }
}
