//
//  Credential.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

class Credential: Hashable {
    /*!
     The credential type (HOTP or TOTP).
     */
    let type: YKFOATHCredentialType;
    
    /*!
     The Issuer of the credential as defined in the Key URI Format specifications:
     https://github.com/google/google-authenticator/wiki/Key-Uri-Format
     */
    let issuer: String;
    
    /*!
     The validity period for a TOTP code, in seconds. The default value for this property is 30.
     If the credential is of HOTP type, this property returns 0.
     */
    let period: UInt;
    
    /*!
     The account name extracted from the label. If the label does not contain the issuer, the
     name is the same as the label.
     */
    let account: String;
    
    let validity : DateInterval
    var code: String
    
    init(fromYKFOATHCredential credential:YKFOATHCredential, otp: String, valid: DateInterval) {
        type = credential.type
        account = credential.account
        issuer = credential.issuer
        period = credential.period
        code = otp
        validity = valid
    }
    
    init(fromYKFOATHCredentialCalculateResult credential:YKFOATHCredentialCalculateResult) {
        type = credential.type
        account = credential.account
        issuer = credential.issuer ?? ""
        period = credential.period
        
        code = credential.otp ?? ""
        validity = credential.validity
    }
    
    var uniqueId: String {
        get {
            if (type == YKFOATHCredentialType.TOTP) {
                return String(format:"%d/%@:%@", period, issuer, account);
            } else {
                return String(format:"%@:%@", issuer, account);
            }
        }
    }
    
    var ykCredential : YKFOATHCredential {
        let credential = YKFOATHCredential()
        credential.account = account
        credential.type = type
        credential.issuer = issuer
        credential.period = period
        credential.label = String(format:"%@:%@", issuer, account)
        return credential
    }
    
    static func == (lhs: Credential, rhs: Credential) -> Bool {
        return lhs.uniqueId == rhs.uniqueId
    }
    
    func hash(into hasher: inout Hasher) {
        return hasher.combine(uniqueId.hashValue)
    }
}
