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

import UIKit
import Combine

class CredentialTableViewCell: UITableViewCell {
    
    var viewModel: OATHViewModel!

    @IBOutlet weak var issuer: UILabel!
    @IBOutlet weak var account: UILabel!
    @IBOutlet weak var onlyAccount: UILabel!
    @IBOutlet weak var codeView: UIView!
    @IBOutlet weak var noCodeCalculated: UILabel!
    @IBOutlet weak var code: UILabel!
    @IBOutlet weak var progress: PieProgressBar!
    @IBOutlet weak var actionIcon: UIImageView!
    @IBOutlet weak var credentialIcon: UILabel!
    @IBOutlet weak var progressScalingConstraint: NSLayoutConstraint!

    @objc dynamic private var credential: Credential?
    private var timerObservation: NSKeyValueObservation?
    private var otpObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var issuerObservation: NSKeyValueObservation?
    private var accountObservation: NSKeyValueObservation?

    private var credentialIconColor: UIColor = .primaryText
    
    override func awakeFromNib() {
        super.awakeFromNib()
        prepareForReuse()
        
        // Dynamic type adjustment of icons is only done when up-scaling
        let progressScaling = UIFontMetrics.default.scaledValue(for: progressScalingConstraint.constant)
        if progressScaling >  progressScalingConstraint.constant {
            progressScalingConstraint.constant = progressScaling
        }
        
        codeView.layer.borderWidth = 1
        codeView.layer.borderColor = UIColor(named: "CodeBorder")?.cgColor
        
        code.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular))
        issuer.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular))
        onlyAccount.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular))
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        // Wait for the next runloop before setting the cornerRadius
        DispatchQueue.main.async {
            self.codeView.layer.cornerRadius = self.codeView.bounds.height / 2.0
        }
    }
    
    override func prepareForReuse() {
        actionIcon.isHidden = true
        progress.isHidden = true
    }
    
    // this method is invoked when table view reloaded and UI got data/list of credentials
    // each cell is responsible to show 1 credential and cell can be reused by updating credential with this method
    func updateView(credential: Credential) {
        self.credential = credential
        refreshName()
        if credential.type == .HOTP {
            let size = UIFontMetrics.default.scaledValue(for: 17)
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "arrow.clockwise.circle.fill", withConfiguration: config)
        } else {
            let size = UIFontMetrics.default.scaledValue(for: 15)
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "hand.tap.fill", withConfiguration: config)
        }
        actionIcon.isHidden = !credential.showActionIcon
        progress.isHidden = !credential.showProgress
        credentialIcon.text = credential.iconLetter
        credentialIconColor = credential.iconColor
        credentialIcon.backgroundColor = credentialIconColor
        progress.setupView()
        refreshCode()
        refreshProgress()

        setupModelObservation()
    }
    
    func animateCode() {
        UIView.animate(withDuration: 0.1, animations: {
            self.codeView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
                self.codeView.transform = CGAffineTransform.identity
            }
        })
    }
    
    // MARK: - Model Observation
    // this allows you to avoid reloading tableview when data in specific credential changes
    // watching changes in view model/credential object and update UI
    private func setupModelObservation() {
        if credential?.type == .TOTP {
            timerObservation = observe(\.credential?.remainingTime, options: [], changeHandler: { (object, change) in
                DispatchQueue.main.async { [weak self] in
                    self?.refreshProgress()
                }
            })
        } else {
            timerObservation = observe(\.credential?.activeTime, options: [], changeHandler: { (object, change) in
                DispatchQueue.main.async { [weak self] in
                    self?.refreshProgress()
                }
            })
        }
        otpObservation = observe(\.credential?.code, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshCode()
            }
        })
        progressObservation = observe(\.credential?.state, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshProgress()
            }
        })
        accountObservation = observe(\.credential?.account, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshName()
            }
        })
        issuerObservation = observe(\.credential?.issuer, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshName()
            }
        })
    }

    // MARK: - UI Refresh
    func refreshName() {
        guard let credential = self.credential else { return }
        if credential.issuer?.isEmpty != true && credential.issuer != nil {
            account.text = credential.account
            account.alpha = 1
            issuer.text = credential.issuer
            issuer.alpha = 1
            onlyAccount.text = nil
        } else {
            onlyAccount.text = credential.account
            issuer.text = "-"
            issuer.alpha = 0
            account.text = "-"
            account.alpha = 0
        }
    }
    
    func refreshProgress() {
        guard let credential = self.credential else {
            return
        }
        if credential.type == .TOTP {
            if credential.remainingTime > 0 {
                progress.setProgress(to: credential.remainingTime / Double(credential.period))
            } else {
                // keeping old value of code on screen even if it's expired already
                progress.setProgress(to: Double(0.0))
            }
        }
        self.actionIcon.isHidden = !credential.showActionIcon
        UIView.animate(withDuration: 0.3) {
            self.progress.isHidden = !credential.showProgress
        }
        code.textColor = credential.codeColor
    }
    
    func refreshCode() {
        guard let credential = self.credential else {
            return
        }
        // There's no font with fixed width for both digits and the dots we use for not calculated codes
        if credential.code == "" {
            noCodeCalculated.isHidden = false
            code.isHidden = true
            code.text = "111 111"
        } else {
            noCodeCalculated.isHidden = true
            code.isHidden = false
            let otp = credential.formattedCode
            code.text = otp
        }
    }
}

extension Credential {
    
    // picking up color for icon from set of colors using hash of unique Id,
    // so that user keeps seeing the same color for item every time he launches the app
    // and we don't need to have map between credential and colors
    var iconColor: UIColor {
#if DEBUG
        // return hard coded nice looking colors for app store screen shots
        if let issuer = self.issuer {
            switch issuer {
            case "Twitter":
                return UIColor(named: "Color5")!
            case "Microsoft":
                return UIColor(named: "Color7")!
            case "GitHub":
                return UIColor(named: "Color8")!
            default:
                break
            }
        }
#endif
        let value = abs(uniqueId.hash) % UIColor.colorSetForAccountIcons.count
        return UIColor.colorSetForAccountIcons[value] ?? .primaryText
    }
    
    var showProgress: Bool {
        if showActionIcon {
            return false
        } else {
            return !requiresRefresh
        }
    }
    
    var showActionIcon: Bool {
        return type == .HOTP || (requiresRefresh && requiresTouch && !SettingsConfig.isBypassTouchEnabled)
    }
    
    var codeColor: UIColor {
        switch type {
        case .HOTP:
            return code.isEmpty ? UIColor.secondaryText : UIColor.primaryText
        case .TOTP:
            return requiresRefresh ? UIColor.secondaryText : UIColor.primaryText
        default:
            return .label // fallback to safe default color
        }
    }
}
