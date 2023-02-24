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
    
    @Published var code: String = ""
    @Published var remaining: Double = 0
    @Published var title: String
    @Published var subTitle: String?
    let id: String
    var color: Color = .red
    var isSteam: Bool = false
    
    var isResigned: Bool = false
    
    var validInterval: DateInterval?
    var timeLeft: Double?
    var timer: Timer? = nil
    var requestRefresh: PassthroughSubject<Account?, Never>?
    
    init(credential: YKFOATHCredential, code: YKFOATHCode?, requestRefresh: PassthroughSubject<Account?, Never>?) {
        id = credential.id
        if let issuer = credential.issuer {
            title = issuer
            subTitle = credential.accountName
        } else {
            title = credential.accountName
        }
        self.requestRefresh = requestRefresh
        self.update(code: code)
        updateRemaining()
        startTimer()
    }
    
    func resign() {
        isResigned = true
    }
    
    func update(code: YKFOATHCode?) {
        guard let code, let otp = code.otp else { self.code = ""; return }
        guard self.code != code.otp else { return }

        self.code = otp
        self.remaining = 1.0
        self.validInterval = code.validity
        self.timeLeft = code.validity.end.timeIntervalSinceNow
        
        if let timeLeft, requestRefresh != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeLeft) { [weak self] in
                guard self?.isResigned == false else { return }
                self?.requestRefresh?.send(nil) // refresh all accounts signaled by sending nil
            }
        }
    }
    
    func pin(_ flag: Bool) async throws {
        // to be implemented
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
        guard validInterval != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRemaining()
        }
    }
    
    func updateRemaining() {
        if let validInterval {
            let timeLeft = validInterval.end.timeIntervalSince(Date())
            self.timeLeft = timeLeft
            if timeLeft > 0 {
                self.remaining = timeLeft / validInterval.duration
            } else {
                self.remaining = 0
            }
        }
    }
}
