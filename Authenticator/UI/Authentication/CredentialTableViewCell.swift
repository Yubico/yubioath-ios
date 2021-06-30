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

    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var code: UILabel!
    @IBOutlet weak var progress: PieProgressBar!
    @IBOutlet weak var favouriteIcon: UIImageView!
    @IBOutlet weak var actionIcon: UIImageView!
    @IBOutlet weak var credentialIcon: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var generateCodeButton: UIButton!
    @IBOutlet weak var copyCodeButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var favoriteIcon: UIImageView!
    
    @objc dynamic private var credential: Credential?
    private var timerObservation: NSKeyValueObservation?
    private var otpObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?

    private var credentialIconColor: UIColor = .primaryText
    
    private var bag = [Cancellable]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
//        copyCodeButton.adjustsImageWhenDisabled = true
//        copyCodeButton.tintAdjustmentMode = .dimmed
        prepareForReuse()
        activityIndicator.startAnimating()
        bag.append(closeButton.addHandler(for: .touchUpInside) {
            self.setSelected(false, animated: true)
        })
        bag.append(copyCodeButton.addHandler(for: .touchUpInside) {
            if let credential = self.credential {
                self.viewModel.copyToClipboard(credential: credential)
            }
            self.setSelected(false, animated: true)
        })
        bag.append(generateCodeButton.addHandler(for: .touchUpInside) {
            self.setSelected(false, animated: true)
            if let credential = self.credential {
                // Slight delay for calculating HOTP so the user can see the code updating
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + (credential.type == .HOTP ? 0.4 : 0)) {
                    self.viewModel.calculate(credential: credential)
                }
            }
        })
    }
    
    override func prepareForReuse() {
        blurView.effect = nil
        actionIcon.isHidden = true
        favouriteIcon.isHidden = true
        progress.isHidden = true
        activityIndicator.isHidden = true
        generateCodeButton.alpha = 0
        copyCodeButton.alpha = 0
        closeButton.alpha = 0
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        print("setSelected \(selected) for \(self.credential!.account)")
        guard let credential = credential else { return }

        if selected {
            UIView.animate(withDuration: 0.5) {
                self.blurView.effect = UIBlurEffect(style: .light)
                if credential.code.isEmpty || credential.type == .HOTP {
                    self.generateCodeButton.alpha = 1.0
                    self.generateCodeButton.isEnabled = true
                } else {
                    self.generateCodeButton.alpha = 0.3
                    self.generateCodeButton.isEnabled = false
                }
                if !credential.code.isEmpty {
                    self.copyCodeButton.alpha = 1
                    self.copyCodeButton.isEnabled = true
                } else {
                    self.copyCodeButton.alpha = 0.3
                    self.copyCodeButton.isEnabled = false
                }
                

                self.closeButton.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.blurView.effect = nil
                self.generateCodeButton.alpha = 0
                self.copyCodeButton.alpha = 0
                self.closeButton.alpha = 0
            }
        }
    }
    
    // this method is invoked when table view reloaded and UI got data/list of credentials
    // each cell is responsible to show 1 credential and cell can be reused by updating credential with this method
    func updateView(credential: Credential, isFavorite: Bool) {
        self.credential = credential
        name.text = credential.issuer?.isEmpty == false ? "\(credential.issuer!) (\(credential.account))" : credential.account
        if credential.type == .HOTP {
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "arrow.clockwise.circle.fill", withConfiguration: config)
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 21, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "hand.tap.fill", withConfiguration: config)
        }
        actionIcon.isHidden = !(credential.requiresTouch || credential.type == .HOTP)
        progress.isHidden = !actionIcon.isHidden || credential.code.isEmpty
        credentialIcon.text = credential.issuer?.isEmpty == false ? String(credential.issuer!.first!).uppercased() : "Y"
        favoriteIcon.isHidden = !isFavorite
        self.credentialIconColor = self.getCredentiaIconlColor(credential: credential)
        credentialIcon.backgroundColor = self.credentialIconColor
        progress.tintColor = .secondaryLabel
        progress.setupView()
        refreshCode()
        refreshProgress()

        setupModelObservation()
    }
    
    // picking up color for icon from set of colors using hash of unique Id,
    // so that user keeps seeing the same color for item every time he launches the app
    // and we don't need to have map between credential and colors
    private func getCredentiaIconlColor(credential: Credential) -> UIColor {
        let value = abs(credential.uniqueId.hash) % UIColor.colorSetForAccountIcons.count
        return UIColor.colorSetForAccountIcons[value] ?? UIColor.primaryText
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
    }


    // MARK: - UI Refresh
    func refreshProgress() {
        guard let credential = self.credential else {
            return
        }
        let requiresRefresh = credential.requiresRefresh
        if credential.state == .calculating {
            self.progress.isHidden = true
            self.actionIcon.isHidden = true
            self.activityIndicator.isHidden = false
        } else if credential.type == .TOTP {
            if credential.remainingTime > 0 {
                self.progress.setProgress(to: credential.remainingTime / Double(credential.period))
            } else {
                // keeping old value of code on screen even if it's expired already
                self.progress.setProgress(to: Double(0.0))
            }
            self.progress.isHidden = requiresRefresh
            self.actionIcon.isHidden = !(self.progress.isHidden && credential.requiresTouch)
            self.activityIndicator.isHidden = true

            // logic of changing color when timout expiration
            if !credential.requiresTouch {
                self.code.textColor = requiresRefresh ? UIColor.secondaryText : UIColor.primaryText
                self.credentialIcon.backgroundColor = requiresRefresh ? UIColor.secondaryText : self.credentialIconColor
            }
        }
    }
    
    func refreshCode() {
        guard let credential = self.credential else {
            return
        }

        var otp = credential.code.isEmpty ? "******" : credential.code
        
        if self.isSelected && credential.code.isEmpty {
            self.copyCodeButton.isEnabled = false
            self.copyCodeButton.alpha = 0.3
            self.generateCodeButton.isEnabled = true
            self.generateCodeButton.alpha = 1.0
        }

        if credential.isSteam {
            self.code.text = otp
        } else {
            // make it pretty by splitting in halves
            otp.insert(" ", at:  otp.index(otp.startIndex, offsetBy: otp.count / 2))
            self.code.text = otp
        }
    }
}
