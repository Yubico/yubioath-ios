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
    @IBOutlet weak var favoriteIcon: UIImageView!
    
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
    }
    
    override func prepareForReuse() {
        actionIcon.isHidden = true
        favouriteIcon.isHidden = true
        progress.isHidden = true
        activityIndicator.isHidden = true
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
        name.text = credential.formattedName
    }
    
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
        let otp = credential.formattedCode
        self.code.text = otp
    }
}
