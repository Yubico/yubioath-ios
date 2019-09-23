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

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        actionIcon.isHidden = true
        progress.isHidden = true
        activityIndicator.isHidden = true
        activityIndicator.startAnimating()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func updateView(credential: Credential) {
        self.credential = credential
        name.text = !credential.issuer.isEmpty ? "\(credential.issuer) (\(credential.account))" : credential.account
        actionIcon.image = UIImage(named: credential.type == .HOTP ? "refresh" : "touch")?.withRenderingMode(.alwaysTemplate)
        actionIcon.isHidden = !(credential.requiresTouch || credential.type == .HOTP)
        progress.isHidden = !actionIcon.isHidden || credential.code.isEmpty
        credentialIcon.text = credential.issuer.isEmpty ? "Y" : String(credential.issuer.first!).uppercased()
            
        refreshCode()
        refreshProgress()

        setupModelObservation()
    }
    
    // MARK: - Model Observation
    
    private func setupModelObservation() {
        if (credential?.type == .TOTP) {
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
        progressObservation = observe(\.credential?.isUpdating, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshProgress()
            }
        })
    }


    // MARK: - Refresh
    func refreshProgress() {
        guard let credential = self.credential else {
            return
        }
        if (credential.isUpdating) {
            self.progress.isHidden = true
            self.actionIcon.isHidden = true
            self.activityIndicator.isHidden = false
        } else if (credential.type == .TOTP && !credential.code.isEmpty) {
            if (credential.remainingTime > 0) {
                self.progress.setProgress(to: credential.remainingTime / Double(credential.period))
            } else {
                // keeping old value of code on screen even if it's expired already
                self.progress.setProgress(to: Double(0.0))
                if (credential.requiresTouch) {
                    credential.code = ""
                }
            }
            self.progress.isHidden = credential.remainingTime <= 0
            self.actionIcon.isHidden = !(self.progress.isHidden && credential.requiresTouch)
            self.activityIndicator.isHidden = true
                // TODO: add logic of changing color or timout expiration
        } else if (credential.type == .HOTP) {
            actionIcon.isHidden = credential.activeTime < 5 && !credential.code.isEmpty
            self.activityIndicator.isHidden = true
        }
    }
    
    func refreshCode() {
        guard let credential = self.credential else {
            return
        }

        var otp = credential.code.isEmpty ? "******" : credential.code

        // make it pretty by splitting in halves
        otp.insert(" ", at:  otp.index(otp.startIndex, offsetBy: otp.count / 2))        
        self.code.text = otp
    }
}
