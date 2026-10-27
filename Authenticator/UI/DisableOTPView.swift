/*
 * Copyright (C) Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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

    @Environment(NotificationsViewModel.self) var notificationsViewModel
    @Environment(MainViewModel.self) var mainViewModel
    @State var model = DisableOTPModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Text("Yubico OTP enabled").font(.title).bold()
                Text("This YubiKey has Yubico OTP enabled which makes it appear as an external keyboard to the iPhone. Unfortunately this causes problem with the normal on-screen keyboard.")
                Spacer().frame(height: 15)
                Button {
                    model.disableOTP()
                } label: {
                    Text("Disable Yubico OTP (recommended)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isConfigurationLocked || model.isDisablingOTP)
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
            }
            .padding(30)
            .accentColor(Color(UIColor.yubiBlue))
            .task {
                model.checkConfigurationLocked()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if ConnectionManager.shared.wiredConnection == nil {
                        mainViewModel.presentDisableOTP = false
                        notificationsViewModel.presentDisableOTP = false
                        break
                    }
                }
            }
            .onChange(of: model.keyIgnored) { _, value in
                if value {
                    mainViewModel.presentDisableOTP = false
                    notificationsViewModel.presentDisableOTP = false
                }
            }
            .errorAlert(error: $model.error)
        }
    }
}

#Preview {
    DisableOTPView()
}
