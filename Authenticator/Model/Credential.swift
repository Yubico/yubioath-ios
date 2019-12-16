//
//  Credential.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

protocol CredentialExpirationDelegate : class {
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
    private static let STEAM_CHARS = Array("23456789BCDFGHJKMNPQRTVWXY")


    /*!
     The credential type (HOTP or TOTP).
     */
    let type: YKFOATHCredentialType
    
    /*!
     The Issuer of the credential as defined in the Key URI Format specifications:
     https://github.com/google/google-authenticator/wiki/Key-Uri-Format
     */
    let issuer: String
    
    /*!
     The validity period for a TOTP code, in seconds. The default value for this property is 30.
     If the credential is of HOTP type, this property returns 0.
     */
    let period: UInt
    
    /*!
     The account name extracted from the label. If the label does not contain the issuer, the
     name is the same as the label.
     */
    let account: String
    
    
    let requiresTouch: Bool

    var validity : DateInterval
    weak var delegate: CredentialExpirationDelegate?
    private var timerObservation: NSKeyValueObservation?

    /*!
     Steam credentials are specific that they represented by letters and digits from STEAM_CHARS array
     We calculate them differently:
     - not truncating to digits number (digits is being ignored)
     - getting INT32 value from Yubikit as string
     - 5 symbols being calculated in algorithm described in formatSteamCode
     */
    var isSteam: Bool {
        get {
            return issuer.lowercased() == Credential.STEAM_ISSUER
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

    init(type: YKFOATHCredentialType = .TOTP, account: String, issuer: String, period: UInt = DEFAULT_PERIOD,  code: String, requiresTouch: Bool = false) {
        self.type = type
        self.account = account
        self.issuer = issuer
        self.period = period
        self.code = code
        self.validity = type == .TOTP ? DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(period)) :
            DateInterval(start: Date(timeIntervalSinceNow: 0), end: Date.distantFuture)
        self.requiresTouch  = requiresTouch
        self.remainingTime = validity.end.timeIntervalSince(Date())
        self.activeTime = 0
        
        if !code.isEmpty {
            state = .active
        }
    }
    
    init(fromYKFOATHCredentialCalculateResult credential:YKFOATHCredentialCalculateResult) {
        type = credential.type
        account = credential.account
        issuer = credential.issuer ?? ""
        period = credential.period
        
        code = credential.otp ?? ""
        validity = credential.validity
        remainingTime = credential.validity.end.timeIntervalSince(Date())
        activeTime = 0
        requiresTouch = credential.requiresTouch
        
        if !code.isEmpty {
            state = .active
        }
    }
    
    // uniqueId is used to store a set of Favorites in UserDefaults.
    // Changing/removing uniqueId will brake FavoritesStorage.
    var uniqueId: String {
        get {
            if type == .TOTP && period != Credential.DEFAULT_PERIOD {
                return String(format:"%@:%@/%d", issuer, account, period).lowercased();
            } else {
                return String(format:"%@:%@", issuer, account).lowercased();
            }
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
            if type == .TOTP && self.remainingTime <= 0 {
                return true
            }
            if type == .HOTP && self.activeTime > 10 {
                return true
            }
            return false
        }
    }
    
    func setCode(code: String, validity : DateInterval) {
        if isSteam {
            self.code = Credential.formatSteamCode(value:code)
        } else {
            self.code = code
        }
        self.validity = validity
        remainingTime = validity.end.timeIntervalSince(Date())
        activeTime = 0
    }
    
    var ykCredential : YKFOATHCredential {
        let credential = YKFOATHCredential()
        credential.account = account
        credential.type = type
        credential.issuer = issuer
        credential.period = period
        
        // STEAM users want to have special type of OTP
        if isSteam {
            credential.notTruncated = true
        }
        return credential
    }
    
    private static func formatSteamCode(value: String) -> String {
        guard !value.isEmpty else {
            return value
        }
        var steamCode = ""
        var intCode = Int(value) ?? 0
        for _ in 0...4 {
            steamCode.append(Credential.STEAM_CHARS[abs(intCode) % STEAM_CHARS.count])
            intCode /= Credential.STEAM_CHARS.count
        }
        return steamCode
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
                        self.code = ""
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
        return lhs.uniqueId < rhs.uniqueId
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
