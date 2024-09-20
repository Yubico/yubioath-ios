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

fileprivate let resetMessageText = String(localized: "Your credentials, as well as any PIN set, will be removed from this YubiKey. Make sure to first disable these from their respective web sites to avoid being locked out of your accounts.")

struct FIDOResetView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject var model = FIDOResetViewModel()
    
    @State var presentConfirmAlert = false
    @State var presentErrorAlert = false
    @State var progress = 0.0
    @State var messageText = resetMessageText
    @State var enableResetButton = true
    @State var errorMessage: String? = nil
    @State var opacity = 1.0

    var body: some View {
        SettingsView(image: Image(systemName: "exclamationmark.triangle").foregroundColor(.red)) {
            Text("FIDO factory reset").font(.headline).opacity(opacity)
            ProgressView(value: progress, total: 4.0).opacity(opacity)
            Text(messageText).multilineTextAlignment(.center)
        } buttons: {
            SettingsButton("Reset FIDO") {
                presentConfirmAlert.toggle()
            }
            .disabled(!enableResetButton)
        }
        .navigationBarTitle(Text("FIDO reset"), displayMode: .inline)
        .alert("Warning!", isPresented: $presentConfirmAlert, presenting: model, actions: { model in
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
        }, message: { _ in
            Text("This will irrevocably delete all U2F and FIDO2 accounts, including passkeys, from your YubiKey.")
        })
        .alert(errorMessage ?? String(localized: "Unknown error"), isPresented: $presentErrorAlert, actions: {
            Button(role: .cancel) {
                errorMessage = nil
                if model.state.isError() {
                    dismiss()
                }
            } label: {
                Text("OK")
            }
        })        
        .onChange(of: model.state) { _ in
            updateState()
        }
        .onAppear() {
            updateState()
        }
    }
    
    func updateState() {
        withAnimation {
            switch model.state {
            case .ready:
                self.enableResetButton = true
                self.messageText = resetMessageText
            case .waitingForKeyRemove:
                self.enableResetButton = false
                self.progress = 1.0
                self.messageText = String(localized: "Unplug your YubiKey.", comment: "FIDO reset view")
            case .waitingForKeyReinsert:
                self.enableResetButton = false
                self.progress = 2.0
                self.messageText = String(localized: "Reinsert your YubiKey.", comment: "FIDO reset view")
            case .waitingForKeyTouch:
                self.progress = 3.0
                self.enableResetButton = false
                self.messageText = String(localized: "Touch the button on the YubiKey now.", comment: "FIDO reset view")
            case .success:
                self.progress = 4.0
                self.opacity = 0.5
                self.enableResetButton = false
                self.messageText = String(localized: "The FIDO application of your YubiKey has been reset to factory defaults.", comment: "FIDO reset view")
            case .error(let error):
                self.enableResetButton = true
                self.presentErrorAlert = true
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
