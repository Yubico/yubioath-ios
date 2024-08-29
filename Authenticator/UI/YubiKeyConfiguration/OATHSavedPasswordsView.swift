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

struct OATHSavedPasswordsView: View {
    
    @StateObject var model = OATHSavedPasswordsViewModel()
    @State var presentConfirmAlert = false
    @State var presentErrorAlert = false
    @State var errorMessage: String? = nil
    @State var passwordsHasBeenCleared = false

    var body: some View {
        SettingsView(image: Image(systemName: "exclamationmark.triangle").foregroundColor(.red)) {
            Text(passwordsHasBeenCleared ? "Saved passwords has been cleared" : "Clear saved OATH passwords").font(.headline)
            Text("Clear passwords saved on this device. This will prompt for a password next time a password protected YubiKey is used.")
                .multilineTextAlignment(.center)
                .opacity(passwordsHasBeenCleared ? 0.2 : 1.0)
        } buttons: {
            SettingsButton("Clear saved passwords") {
                presentConfirmAlert.toggle()
            }
            .disabled(passwordsHasBeenCleared)
        }
        .navigationBarTitle(Text("Clear saved passwords"), displayMode: .inline)
        .alert("Clear passwords", isPresented: $presentConfirmAlert, presenting: model, actions: { model in
            Button(role: .destructive) {
                presentConfirmAlert.toggle()
                model.clearPasswords()
            } label: {
                Text("OK")
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
                    self.passwordsHasBeenCleared = false
                case .success:
                    self.passwordsHasBeenCleared = true
                case .error(let message):
                    self.presentErrorAlert = true
                    self.errorMessage = message
                }
            }
        }
    }
}
