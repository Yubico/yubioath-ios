//
//  CredentialTableViewCell.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/24/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class CredentialTableViewCell: UITableViewCell {

    @IBOutlet weak var issuer: UILabel!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var code: UILabel!
    @IBOutlet weak var progress: CircularProgressBar!
    
    weak var credential: Credential?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func updateView(credential: Credential) {
        self.credential = credential
        var otp = credential.code
        // make it pretty by splitting in halves
        otp.insert(" ", at:  otp.index(otp.startIndex, offsetBy: otp.count / 2))
        code.text = otp
        issuer.text = credential.issuer
        name.text = credential.account
        
        if (credential.type == .TOTP && !credential.code.isEmpty) {
            // set up progress timer by watchin global timer changes
            refreshProgress()
        } else {
            progress.isHidden = true
        }
    }

    // MARK: - Refresh
    func refreshProgress() {
        guard let credential = self.credential else {
            return
        }
        if (credential.type == .TOTP && !credential.code.isEmpty) {
            let remainingTime = credential.validity.end.timeIntervalSince(Date())
            if (remainingTime > 0) {
                self.progress.setProgress(to: Double(remainingTime) / Double(credential.period), duration: 0.0, withAnimation: false)
            } else {
                self.progress.setProgress(to: Double(0.0), duration: 0.0, withAnimation: false)
            }
                // TODO: add logic of changing color or timout expiration
        }
    }
}
