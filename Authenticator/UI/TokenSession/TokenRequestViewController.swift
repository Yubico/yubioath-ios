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
    @IBOutlet weak var orView: UIView!
    @IBOutlet weak var nfcView: UIView!
    @IBOutlet weak var passwordTextField: UITextField!
    var viewModel: TokenRequestViewModel?
    var defaultAccessoryTest: String?
    @IBOutlet weak var overlayView: UIView!
    @IBOutlet weak var arrowHintView: UIView!
    @IBOutlet weak var checkmarkView: UIView!
    @IBOutlet weak var checkmarkTextView: UIView!

    @IBOutlet weak var topHeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var headingAccessoryContstraint: NSLayoutConstraint!
    @IBOutlet weak var accessoryOrConstraint: NSLayoutConstraint!
    @IBOutlet weak var orNFCConstraint: NSLayoutConstraint!
    @IBOutlet weak var nfcPinInputConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        defaultAccessoryTest = accessoryLabel.text
        overlayView.alpha = 0
        arrowHintView.alpha = 0
        checkmarkView.alpha = 0
        checkmarkTextView.alpha = 0
        passwordTextField.textContentType = .oneTimeCode
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // We need to tighten the vertical spacing to make room for the keyboard on smaller screens
        if UIScreen.main.bounds.width <= 320 {
            topHeadingConstraint.constant = 40
            headingAccessoryContstraint.constant = 35
            accessoryOrConstraint.constant = 5
            orNFCConstraint.constant = 5
            nfcPinInputConstraint.constant = 35
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel = TokenRequestViewModel()
        passwordTextField.becomeFirstResponder()
        viewModel?.isAccessoryKeyConnected { [weak self] connected in
            UIView.animate(withDuration: 0.2) {
                self?.orView.alpha = 0
                self?.nfcView.alpha = 0
                self?.accessoryLabel.alpha = 0
            } completion: { _ in
                UIView.animate(withDuration: 0.2) {
                    self?.accessoryLabel.alpha = 1
                    if connected {
                        self?.accessoryLabel.text = "Enter the PIN to access the certificate."
                    } else {
                        self?.accessoryLabel.text = self?.defaultAccessoryTest
                        self?.orView.alpha = 1
                        self?.nfcView.alpha = 1
                    }
                }
            }
        }
    }
    
    @objc func didEnterBackground() {
        viewModel?.cancel()
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
                UIView.animate(withDuration: 2) {
                    self.checkmarkView.alpha = 1
                    self.checkmarkTextView.alpha = 1
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
        UIView.animateKeyframes(withDuration: 7, delay: 5, options: .calculationModeCubicPaced) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1.0/7.0) {
                self.arrowHintView.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 1.0/7.0, relativeDuration: 1.0/7.0) {
                self.arrowHintView.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 2.0/7.0, relativeDuration: 1.0/7.0) {
                self.arrowHintView.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 3.0/7.0, relativeDuration: 1.0/7.0) {
                self.arrowHintView.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 4.0/7.0, relativeDuration: 1.0/7.0) {
                self.arrowHintView.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 3.0/7.0, relativeDuration: 1.0/7.0) {
                self.arrowHintView.alpha = 0
            }
            UIView.addKeyframe(withRelativeStartTime: 4.0/7.0, relativeDuration: 1.0/7.0) {
                self.arrowHintView.alpha = 1
            }
        }
    }
}


extension UIScreen {
    static var isZoomed: Bool {
        return self.main.scale < self.main.nativeScale
    }
}
