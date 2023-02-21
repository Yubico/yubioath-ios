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
    
    @Published var code: String
    @Published var remaining: Double = 0
    @Published var title: String
    @Published var subTitle: String?
    let id: String
    var color: Color = .red
    var isSteam: Bool = false
    
    var validInterval: DateInterval?
    var timeLeft: Double?
    var timer: Timer? = nil
    var requestRefresh: PassthroughSubject<Void, Never>
    
    init(credential: YKFOATHCredential, code: YKFOATHCode?, requestRefresh: PassthroughSubject<Void, Never>) {
        id = credential.id
        if let issuer = credential.issuer {
            title = issuer
            subTitle = credential.accountName
        } else {
            title = credential.accountName
        }
        
        if let code {
            self.code = code.otp ?? ""
        } else {
            self.code = ""
        }
        
        self.validInterval = code?.validity
        self.timeLeft = self.validInterval?.end.timeIntervalSinceNow
        self.requestRefresh = requestRefresh
        
        if let timeLeft {
            DispatchQueue.main.asyncAfter(deadline: .now() + timeLeft) { [weak self] in
                self?.requestRefresh.send()
            }
        }
        
        updateRemaining()
        startTimer()
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
