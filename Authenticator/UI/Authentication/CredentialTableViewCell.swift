//
//  CredentialTableViewCell.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/24/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

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
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var iconScalingConstraint: NSLayoutConstraint!
    
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
        activityIndicator.startAnimating()
        
        // Dynamic type adjustment of icons is only done when up-scaling
        let progressSize = UIFontMetrics.default.scaledValue(for: progress.frame.size.height)
        if progressSize > progress.frame.size.height {
            progress.frame.size = CGSize(width: progressSize, height: progressSize)
        }
        
        let iconScaling = UIFontMetrics.default.scaledValue(for: iconScalingConstraint.constant)
        if iconScaling > iconScalingConstraint.constant {
            iconScalingConstraint.constant = iconScaling
        }
        codeView.layer.borderWidth = 1
        codeView.layer.borderColor = UIColor(named: "CodeBorder")?.cgColor
    }
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        // Wait for the next runloop before setting the cornerRadius
        DispatchQueue.main.async {
            self.codeView.layer.cornerRadius = self.codeView.bounds.height / 2.0
        }
    }
    
    override func prepareForReuse() {
        code.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: 19, weight: .regular))
        
        issuer.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: 19, weight: .regular))
        onlyAccount.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.monospacedDigitSystemFont(ofSize: 19, weight: .regular))
        
        code.adjustsFontForContentSizeCategory = true
        actionIcon.isHidden = true
        progress.isHidden = true
        activityIndicator.isHidden = true
    }
    
    // this method is invoked when table view reloaded and UI got data/list of credentials
    // each cell is responsible to show 1 credential and cell can be reused by updating credential with this method
    func updateView(credential: Credential) {
        self.credential = credential
        refreshName()
        if credential.type == .HOTP {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "arrow.clockwise.circle.fill", withConfiguration: config)
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "hand.tap.fill", withConfiguration: config)
        }
        actionIcon.isHidden = !(credential.requiresTouch || credential.type == .HOTP)
        progress.isHidden = !actionIcon.isHidden || credential.code.isEmpty
        credentialIcon.text = credential.iconLetter
        self.credentialIconColor = credential.iconColor
        credentialIcon.backgroundColor = self.credentialIconColor
        progress.setupView()
        refreshCode()
        refreshProgress()

        setupModelObservation()
    }
    
    func animateCode() {
        UIView.animate(withDuration: 0.1, animations: {
            self.codeView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
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
                self.progress.setProgress(to: credential.remainingTime / Double(credential.period))
            } else {
                // keeping old value of code on screen even if it's expired already
                self.progress.setProgress(to: Double(0.0))
            }
            self.progress.isHidden = credential.requiresRefresh
            self.actionIcon.isHidden = !(credential.requiresRefresh && credential.requiresTouch && !SettingsConfig.isBypassTouchEnabled)
            self.activityIndicator.isHidden = true
            self.code.textColor = credential.requiresRefresh ? UIColor.secondaryText : UIColor.primaryText
        } else if credential.type == .HOTP {
            self.code.textColor = credential.code.isEmpty ? UIColor.secondaryText : UIColor.primaryText
        }
    }
    
    func refreshCode() {
        guard let credential = self.credential else {
            return
        }
        // There's no font with fixed width for both digits and the dots we use for not calculated codes
        if credential.code == "" {
            noCodeCalculated.isHidden = false
            code.isHidden = true
            self.code.text = "111 111"
        } else {
            noCodeCalculated.isHidden = true
            code.isHidden = false
            let otp = credential.formattedCode
            self.code.text = otp
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
        let value = abs(self.uniqueId.hash) % UIColor.colorSetForAccountIcons.count
        return UIColor.colorSetForAccountIcons[value] ?? .primaryText
    }
}
