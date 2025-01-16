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
    @State var image = Image(systemName: "xmark.circle")
    @State var imageColor = Color(.systemRed)

    var body: some View {
        SettingsView(image: image, imageColor: imageColor) {
            Text("Clear saved OATH passwords")
                .multilineTextAlignment(.center)
                .font(.title2)
                .bold()
                .opacity(passwordsHasBeenCleared ? 0.2 : 1.0)
            Text("Clear passwords saved on this device. This will prompt for a password next time a password protected YubiKey is used.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .opacity(passwordsHasBeenCleared ? 0.2 : 1.0)
        } buttons: {
            SettingsButton(String(localized: "Clear saved passwords")) {
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
        .alert(errorMessage ?? String(localized: "Unknown error"), isPresented: $presentErrorAlert, actions: { })
        .onChange(of: model.state) { state in
            withAnimation {
                switch state {
                case .ready:
                    self.passwordsHasBeenCleared = false
                case .success:
                    self.passwordsHasBeenCleared = true
                    self.image = Image(systemName: "checkmark.circle")
                    self.imageColor = Color(.systemGreen)
                case .error(let message):
                    self.presentErrorAlert = true
                    self.errorMessage = message
                }
            }
        }
    }
}
