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

struct DisableOTPView: View {
    
    @EnvironmentObject var mainViewModel: MainViewModel
    @StateObject var model = DisableOTPModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                if !model.otpDisabled {
                    Text("Yubico OTP enabled").font(.title).bold()
                    Text("This YubiKey has Yubico OTP enabled which makes it appear as an external keyboard to the iPhone. Unfortunately this causes problem with the normal on-screen keyboard.")
                    Spacer().frame(height: 15)
                    Button {
                        model.disableOTP()
                    } label: {
                        Text("Disable Yubico OTP (recommended)")
                            .frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent)
                    Text("Disabling Yubico OTP will prevent the YubiKey from appearing as a keyboard. If you don’t use Yubico OTP this is the recommended solution. This can be re-enabled from the settings page.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer().frame(height: 25)
                    Button {
                        model.ignoreThisKey()
                    } label: {
                        Text("Continue with limited usability")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    Text("While the YubiKey is inserted the on-screen keyboard will not appear. To show the keyboard you will have to remove the YubiKey and then re-insert it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    Text("Yubico OTP has been disabled").font(.title).bold()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    Spacer().frame(height: 15)
                    Text("Remove and re-insert your YubiKey")
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    Spacer()
                }
            }
            .padding(30)
            .accentColor(Color(UIColor.yubiBlue))
            .onChange(of: model.keyRemoved, perform: { value in
                mainViewModel.start()
                mainViewModel.presentDisableOTP = false
            })
            .onChange(of: model.keyIgnored, perform: { value in
                mainViewModel.start()
                mainViewModel.presentDisableOTP = false
            })
        }
    }
}

#Preview {
    DisableOTPView()
}
