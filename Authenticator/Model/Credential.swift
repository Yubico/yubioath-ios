//
//  Credential.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

protocol CredentialExpirationDelegate : AnyObject {
    func calculateResultDidExpire(_ credential: Credential)
}

/*! Model class that represent data for each account/credetial
 * Does not have any knowledge about UI and how it's going to be represented
 * Doesn't have any delegates, so it's suggested to use observers to watch changes in that object
 * It is using observers to get updates on it's properties (code/remainingTime/activeTime/state)
 * It's responsibility of user to start observers and remove them before deallocating, otherwise observer could lead to crash
 * Make sure that you don't have multithreading issue with observers (e.g. do not stop observer while it's just started on another thread)
 */
class Credential: NSObject {
    static let DEFAULT_PERIOD: UInt = 30
    private static let STEAM_ISSUER = "steam"
    
    /*!
     Firmware version of the key that generated the credential.
     */
    let keyVersion: YKFVersion
    
    /*!
     The credential type (HOTP or TOTP).
     */
    let type: YKFOATHCredentialType
    
    /*!
     The Issuer of the credential as defined in the Key URI Format specifications:
     https://github.com/google/google-authenticator/wiki/Key-Uri-Format
     */
    @objc dynamic var issuer: String?
    
    /*!
     The validity period for a TOTP code, in seconds. The default value for this property is 30.
     If the credential is of HOTP type, this property returns 0.
     */
    let period: UInt
    
    /*!
     The account name extracted from the label. If the label does not contain the issuer, the
     name is the same as the label.
     */
    @objc dynamic var account: String
    
    
    let requiresTouch: Bool

    var validity : DateInterval
    weak var delegate: CredentialExpirationDelegate?
    private var timerObservation: NSKeyValueObservation?

    var isSteam: Bool {
        get {
            return type == .TOTP && issuer?.lowercased() == Credential.STEAM_ISSUER
        }
    }
    
    @objc dynamic var code: String
    @objc dynamic var remainingTime : Double
    @objc dynamic var activeTime : Double
    @objc dynamic var state : CredentialState = .idle

    /*! This is reference to static timer
     * watching its ticks to calculate how much time since last OTP recalculation(activeTime) and how much time it's still valid (remainingTime)
     *
     */
    @objc dynamic private var globalTimer = GlobalTimer.shared

    init(type: YKFOATHCredentialType = .TOTP, account: String, issuer: String, period: UInt = DEFAULT_PERIOD,  code: String, requiresTouch: Bool = false, keyVersion: YKFVersion) {
        self.keyVersion = keyVersion
        self.type = type
        self.account = account
        self.issuer = issuer
        self.period = period
        self.validity = type == .TOTP ? DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(period)) :
            DateInterval(start: Date(timeIntervalSinceNow: 0), end: Date.distantFuture)
        self.requiresTouch  = requiresTouch
        self.remainingTime = validity.end.timeIntervalSince(Date())
        self.activeTime = 0
        self.code = code

        super.init()
        if !code.isEmpty {
            state = .active
        }
    }
    
    init(credential: YKFOATHCredentialWithCode, keyVersion: YKFVersion) {
        self.keyVersion = keyVersion
        type = credential.credential.type
        account = credential.credential.accountName
        issuer = credential.credential.issuer
        period = credential.credential.period
        validity = credential.code?.validity ?? DateInterval()
        remainingTime = credential.code?.validity.end.timeIntervalSince(Date()) ?? 0
        activeTime = 0
        requiresTouch = credential.credential.requiresTouch
        code = credential.code?.otp ?? ""

        super.init()
        if !code.isEmpty {
            state = .active
        }
    }
    
    // uniqueId is used to store a set of Favorites in UserDefaults.
    // Changing/removing uniqueId will brake FavoritesStorage.
    var uniqueId: String {
        get {
            var id = ""
            if let issuer = issuer {
                id += issuer + ":"
            }
            id += account
            if type == .TOTP && period != Credential.DEFAULT_PERIOD {
                id += "/" + String(period)
            }
            
            return id
        }
    }
    
    var requiresRefresh: Bool {
        get {
            if code.isEmpty {
                return true
            }
            if state == .expired || state == .idle {
                return true
            }
            if type == .TOTP && self.remainingTime < -100 { // kludge of the week
                return true
            }
            if type == .HOTP && self.activeTime > 10 {
                return true
            }
            return false
        }
    }
    
    func setCode(code: String, validity : DateInterval) {
        self.code = code
        self.validity = validity
        remainingTime = validity.end.timeIntervalSince(Date())
        activeTime = 0
    }
    
    var ykCredential : YKFOATHCredential {
        let credential = YKFOATHCredential()
        credential.accountName = account
        credential.type = type
        credential.issuer = issuer
        credential.period = period
        return credential
    }
    
    // MARK: - Observation
    
    // set up timer to get notified about expiration (by watching global timer changes)
    func setupTimerObservation() {
        if self.code.isEmpty {
            return
        }
        timerObservation = observe(\.globalTimer.tick, options: [.initial], changeHandler: { [weak self] (object, change) in
            guard let self = self else {
                return
            }
            if self.timerObservation == nil {
                // timer is ignored
                return
            }
            
            self.activeTime += 1;
            
            // HOTP credential track only active time and no remaining time
            if self.type == .HOTP {
                return
            }

            self.remainingTime = self.validity.end.timeIntervalSince(Date())
            if self.remainingTime <= 0 {
                DispatchQueue.main.async { [weak self] in
                    // we don't update automatically credentials that require touch
                    guard let self = self else {
                        return
                    }
                    if !self.requiresTouch {
                        self.delegate?.calculateResultDidExpire(self)
                    } else {
                        self.state = .expired
                    }

                    // we need to remove observers on UI thread because we can have other operations
                    // (e.g. calculateAll or delete) asynchronously change that state
                    // TODO: provide another dispatcher for it (other than main thread)
                    self.removeTimerObservation()
                }
            }
        })
    }
    
    func removeTimerObservation() {
        timerObservation = nil
    }
    
    static func == (lhs: Credential, rhs: Credential) -> Bool {
        return lhs.uniqueId == rhs.uniqueId
    }

    static func < (lhs: Credential, rhs: Credential) -> Bool {
        return lhs.uniqueId.lowercased() < rhs.uniqueId.lowercased()
    }

    /*! Variation of states for credential
     * idle - just created from list
     * calculating - the operation of calculation is poped from queue and started execution
     * expired 
     */
    @objc enum CredentialState : Int {
        case idle
        case calculating
        case expired
        case active
    }
}

extension Credential {
    var formattedName: String {
        return issuer?.isEmpty == false ? "\(issuer!) (\(account))" : account
    }
    
    var formattedCode: String {
        var otp = self.code.isEmpty ? "••••••" : self.code
        if self.isSteam {
            return otp
        } else {
            // make it pretty by splitting in halves
            otp.insert(" ", at:  otp.index(otp.startIndex, offsetBy: otp.count / 2))
            return otp
        }
    }
    
    var iconLetter: String {
        if let issuer = issuer?.first?.uppercased() {
            return issuer
        } else if let account = account.first?.uppercased() {
            return account
        } else {
            return "Y"
        }
    }
}
