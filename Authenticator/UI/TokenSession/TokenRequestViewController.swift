/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation

@available(iOS 14.0, *)
class TokenRequestViewController: UIViewController, UITextFieldDelegate {
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        defaultAccessoryTest = accessoryLabel.text
        overlayView.alpha = 0
        arrowHintView.alpha = 0
        checkmarkView.alpha = 0
        checkmarkTextView.alpha = 0
        passwordTextField.textContentType = .oneTimeCode
        if !YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            orView.alpha = 0
            nfcView.alpha = 0
        } else {
            orView.alpha = 1
            nfcView.alpha = 1
        }
        
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
        passwordTextField.delegate = self
        
        viewModel?.isYubiOTPEnabledOverUSBC { yubiOTPEnabled in
            if let yubiOTPEnabled, yubiOTPEnabled == true {
                DispatchQueue.main.async {
                    let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc: TokenRequestYubiOTPViewController = storyboard.instantiateViewController(withIdentifier: "TokenRequestYubiOTPViewController") as! TokenRequestYubiOTPViewController
                    vc.viewModel = self.viewModel
                    vc.modalPresentationStyle = .fullScreen
                    self.present(vc, animated: true)
                }
            }
            
            self.viewModel?.isWiredKeyConnected { [weak self] connected in
                if !connected && self?.orView.alpha == 1 { return }
                UIView.animate(withDuration: 0.2) {
                    self?.orView.alpha = 0
                    self?.nfcView.alpha = 0
                    self?.accessoryLabel.alpha = 0
                } completion: { _ in
                    UIView.animate(withDuration: 0.2) {
                        self?.accessoryLabel.alpha = 1
                        if connected {
                            self?.accessoryLabel.text = String(localized: "Enter the PIN to access the certificate.", comment: "PIV extension enter PIN message")
                        } else {
                            self?.accessoryLabel.text = self?.defaultAccessoryTest
                            if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
                                self?.orView.alpha = 1
                                self?.nfcView.alpha = 1
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func didEnterBackground() {
        self.viewModel?.cancel()
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
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string).replacingOccurrences(of: "\n", with: "")
        return updatedText.count <= 8
    }
}

@available(iOS 14.0, *)
extension TokenRequestViewController {
    
    func animateHint() {
        UIView.animate(withDuration: 1, delay: 4, options: .curveEaseInOut) {
            self.arrowHintView.alpha = 1
            self.arrowHintView.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
        } completion: { _ in
            UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut) {
                self.arrowHintView.alpha = 0
                self.arrowHintView.transform = CGAffineTransform(scaleX: 1, y: 1)
            } completion: { _ in
                UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut) {
                    self.arrowHintView.alpha = 1
                    self.arrowHintView.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
                } completion: { _ in
                    UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut) {
                        self.arrowHintView.alpha = 0
                        self.arrowHintView.transform = CGAffineTransform(scaleX: 1, y: 1)
                    } completion: { _ in
                        UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut) {
                            self.arrowHintView.alpha = 1
                            self.arrowHintView.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
                        } completion: { _ in
                            UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut) {
                                self.arrowHintView.alpha = 0
                                self.arrowHintView.transform = CGAffineTransform(scaleX: 1, y: 1)
                            } completion: { _ in
                                UIView.animate(withDuration: 1, delay: 0, options: .curveEaseInOut) {
                                    self.arrowHintView.alpha = 1
                                    self.arrowHintView.transform = CGAffineTransform(scaleX: 1.8, y: 1.8)
                                } completion: { _ in
                                    UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseInOut) {
                                        self.arrowHintView.alpha = 1
                                        self.arrowHintView.transform = CGAffineTransform(scaleX: 1, y: 1)
                                    } completion: { _ in
                                        print("done")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


extension UIScreen {
    static var isZoomed: Bool {
        return self.main.scale < self.main.nativeScale
    }
}
