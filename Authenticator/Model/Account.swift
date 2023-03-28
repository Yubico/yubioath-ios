/*
 * Copyright (C) Yubico.
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

import SwiftUI
import Combine

class Account: ObservableObject {
    
    enum AccountState {
        case counter(Double)
        case requiresTouch
        case calculate
    }
    
    @Published var otp: OATHSession.OTP?
    @Published var title: String
    @Published var subTitle: String?
    @Published var state: AccountState
    @Published var isPinned: Bool
    
    var id: String { credential.id }
    var color: Color = .red
    var isResigned: Bool = false
    var enableRefresh: Bool = true
    var timeLeft: Double?
    var timer: Timer? = nil
    var requestRefresh: PassthroughSubject<Account?, Never>
    var connectionType: OATHSession.ConnectionType
    var credential: OATHSession.Credential
    var keyVersion: YKFVersion
    
    init(credential: OATHSession.Credential, code: OATHSession.OTP?, keyVersion: YKFVersion, requestRefresh: PassthroughSubject<Account?, Never>, connectionType: OATHSession.ConnectionType, isPinned: Bool) {
        self.credential = credential
        title = credential.title
        subTitle = credential.subTitle
        self.isPinned = isPinned
        self.keyVersion = keyVersion
        
        if credential.requiresTouch {
            state = .requiresTouch
        } else if credential.type == .hotp {
            state = .calculate
        } else {
            enableRefresh = false
            state = .counter(1.0)
        }
        self.connectionType = connectionType
        self.requestRefresh = requestRefresh
        self.update(otp: code)
    }
    
    func resign() {
        isResigned = true
    }
    
    func updateTitles() {
        title = credential.title
        subTitle = credential.subTitle
    }
    
    func update(otp: OATHSession.OTP?) {
        guard self.otp != otp, let otp else { return }
        self.otp = otp
        
        if self.credential.type == .totp {
            self.timeLeft = otp.validity.end.timeIntervalSinceNow
            
            // Schedule refresh if connection is wired
            if let timeLeft, connectionType == .wired {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeLeft) { [weak self] in
                    guard self?.isResigned == false else { return }
                    self?.requestRefresh.send(nil) // refresh all accounts signaled by sending nil
                }
            }
            
            updateRemaining()
            startTimer()
        } else {
            self.state = .calculate
        }
    }
    
    var formattedCode: String? {
        guard let otp else { return nil }
        if self.credential.isSteam {
            return otp.code
        } else {
            // make it pretty by splitting in halves
            var formattedCode = otp.code
            formattedCode.insert(" ", at:  formattedCode.index(formattedCode.startIndex, offsetBy: formattedCode.count / 2))
            return formattedCode
        }
    }
    
    var iconColor: Color {
#if DEBUG
        // return hard coded nice looking colors for app store screen shots
        switch self.title {
        case "Twitter":
            return Color("Color5")
        case "Microsoft":
            return Color("Color7")
        case "GitHub":
            return Color("Color8")
        default:
            break
        }
#endif
        let value = abs(id.hash) % UIColor.colorSetForAccountIcons.count
        return Color(UIColor.colorSetForAccountIcons[value] ?? .primaryText)
    }

    
    func startTimer() {
        self.timer?.invalidate()
        guard otp?.validity != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRemaining()
        }
    }
    
    func updateRemaining() {
        if let validInterval = otp?.validity {
            let timeLeft = validInterval.end.timeIntervalSince(Date())
            self.timeLeft = timeLeft
            if timeLeft > 0 {
                self.state = .counter(timeLeft / validInterval.duration)
                self.enableRefresh = false
            } else if connectionType == .nfc { // If no request refresh pass through this account is from a NFC key
                self.state = self.credential.requiresTouch ? .requiresTouch : .calculate
                self.timer?.invalidate()
                self.timer = nil
                self.enableRefresh = true
            } else {
                self.state = .counter(1.0)
                self.enableRefresh = false
            }
        }
    }
}

extension Account: Comparable {
    static func == (lhs: Account, rhs: Account) -> Bool {
        return lhs.id.lowercased() == rhs.id.lowercased()
    }

    static func < (lhs: Account, rhs: Account) -> Bool {
        return lhs.id.lowercased() < rhs.id.lowercased()
    }
}

extension OATHSession.Credential {
    var title: String {
        if let issuer, issuer.isEmpty == false {
            return issuer
        } else {
            return accountName
        }
    }
    var subTitle: String? {
        if issuer != nil && issuer?.isEmpty == false {
            return accountName
        } else {
            return nil
        }
    }
}
