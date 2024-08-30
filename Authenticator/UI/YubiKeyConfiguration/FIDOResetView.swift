/*
 * Copyright (C) 2022 Yubico.
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

struct FIDOResetView: View {
    
    @StateObject var model = FIDOResetViewModel()
    @State var presentConfirmAlert = false
    @State var presentErrorAlert = false
    @State var keyHasBeenReset = false
    @State var errorMessage: String? = nil

    var body: some View {
        SettingsView(image: Image(systemName: "exclamationmark.triangle").foregroundColor(.red)) {
            Text(keyHasBeenReset ? "FIDO has been reset" : "Reset FIDO application").font(.headline)
            Text("Reset all FIDO accounts stored on YubiKey, make sure they are not in use anywhere before doing this.")
                .multilineTextAlignment(.center)
                .opacity(keyHasBeenReset ? 0.2 : 1.0)
        } buttons: {
            SettingsButton("Reset Yubikey") {
                presentConfirmAlert.toggle()
            }
            .disabled(keyHasBeenReset)
        }
        .navigationBarTitle(Text("Reset FIDO"), displayMode: .inline)
        .alert("Confirm FIDO reset", isPresented: $presentConfirmAlert, presenting: model, actions: { model in
            Button(role: .destructive) {
                presentConfirmAlert.toggle()
                model.reset()
            } label: {
                Text("Reset")
            }
            Button(role: .cancel) {
                presentConfirmAlert.toggle()
            } label: {
                Text("Cancel")
            }
        })
        .alert(errorMessage ?? "Unknown error", isPresented: $presentErrorAlert, actions: { })
        .onChange(of: model.state) { state in
            withAnimation {
                switch state {
                case .ready:
                    self.keyHasBeenReset = false
                case .success:
                    self.keyHasBeenReset = true
                case .error(let message):
                    self.presentErrorAlert = true
                    self.errorMessage = message
                }
            }
        }
    }
}
