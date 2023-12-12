//
//  TokenRequestYubiOTP.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-12-11.
//  Copyright © 2023 Yubico. All rights reserved.
//

import Foundation

@available(iOS 14.0, *)
class TokenRequestYubiOTPViewController: UIViewController {
    
    var viewModel: TokenRequestViewModel?

    @IBOutlet weak var optionsView: UIStackView!
    @IBOutlet weak var completedView: UIStackView!
    
    @IBAction func disableOTP() {
        viewModel?.disableOTP { error in
            guard error == nil else { return }
            UIView.animate(withDuration: 0.5) {
                DispatchQueue.main.async {
                    self.optionsView.alpha = 0
                    self.completedView.alpha = 1
                    self.viewModel?.waitForKeyRemoval {
                        self.dismiss(animated: true)
                    }
                }
            }
        }
    }
    
    @IBAction func ignoreThisKey() {
        viewModel?.ignoreThisKey { error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                self.dismiss(animated: true)
            }
        }
    }
}
