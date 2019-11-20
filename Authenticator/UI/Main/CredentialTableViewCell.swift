//
//  CredentialTableViewCell.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/24/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class CredentialTableViewCell: UITableViewCell {

    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var code: UILabel!
    @IBOutlet weak var progress: PieProgressBar!
    @IBOutlet weak var actionIcon: UIImageView!
    @IBOutlet weak var credentialIcon: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    @objc dynamic private var credential: Credential?
    private var timerObservation: NSKeyValueObservation?
    private var otpObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?

    private var credentialIconColor: UIColor = .primaryText
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        actionIcon.isHidden = true
        progress.isHidden = true
        activityIndicator.isHidden = true
        activityIndicator.startAnimating()
    }
    
    // this method is invoked when table view reloaded and UI got data/list of credentials
    // each cell is responsible to show 1 credential and cell can be reused by updating credential with this method
    func updateView(credential: Credential) {
        self.credential = credential
        name.text = !credential.issuer.isEmpty ? "\(credential.issuer) (\(credential.account))" : credential.account
        actionIcon.image = UIImage(named: credential.type == .HOTP ? "refresh" : "touch")?.withRenderingMode(.alwaysTemplate)
        actionIcon.isHidden = !(credential.requiresTouch || credential.type == .HOTP)
        progress.isHidden = !actionIcon.isHidden || credential.code.isEmpty
        credentialIcon.text = credential.issuer.isEmpty ? "Y" : String(credential.issuer.first!).uppercased()
        
        self.credentialIconColor = self.getCredentiaIconlColor(credential: credential)
        credentialIcon.backgroundColor = self.credentialIconColor
        progress.tintColor = self.credentialIconColor
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

        } else if credential.type == .HOTP {
            actionIcon.isHidden = !requiresRefresh
            self.activityIndicator.isHidden = true
        }
        
        // logic of changing color when timout expiration
        self.code.textColor = requiresRefresh ? UIColor.secondaryText : UIColor.primaryText
        self.credentialIcon.backgroundColor = requiresRefresh ? UIColor.secondaryText : self.credentialIconColor
    }
    
    func refreshCode() {
        guard let credential = self.credential else {
            return
        }

        var otp = credential.code.isEmpty ? "******" : credential.code

        if credential.isSteam {
            self.code.text = otp
        } else {
            // make it pretty by splitting in halves
            otp.insert(" ", at:  otp.index(otp.startIndex, offsetBy: otp.count / 2))
            self.code.text = otp
        }
    }
}
