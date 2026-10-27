//
//  TokenRequestYubiOTP.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-12-11.
//  Copyright © 2023 Yubico. All rights reserved.
//  Copyright © 2026 Kenzi Voyer.
//

import Foundation

@available(iOS 14.0, *)
class TokenRequestYubiOTPViewController: UIViewController {
    
    var viewModel: TokenRequestViewModel?

    @IBOutlet weak var optionsView: UIStackView!
    @IBOutlet weak var completedView: UIStackView!
    
    
    override func viewDidLoad() {
        Task { [weak self] in
            await self?.viewModel?.waitForKeyRemoval()
            self?.dismiss(animated: true)
        }
    }
    
    @IBAction func disableOTP() {
        guard let viewModel else { return }
        Task {
            do {
                try await viewModel.disableOTP()
                UIView.animate(withDuration: 0.5) {
                    self.optionsView.alpha = 0
                    self.completedView.alpha = 1
                }
            } catch {
                self.presentError(error)
            }
        }
    }
    
    @IBAction func ignoreThisKey() {
        guard let viewModel else { return }
        Task {
            do {
                try await viewModel.ignoreThisKey()
                self.dismiss(animated: true)
            } catch {
                self.presentError(error)
            }
        }
    }
    
    private func presentError(_ error: Error?) {
        guard let error else { return }
        let alert = UIAlertController(title: String(localized: "Error reading YubiKey", comment: "PIV extension error title"), message: "\(LocalizedErrorWrapper(error: error).localizedDescription)\n\n\(String(localized: "Remove and reinsert your YubiKey", comment: "PIV extension error reinsert key")).") { self.dismiss(animated: true) }
        self.present(alert, animated: true, completion: nil)
    }
}
