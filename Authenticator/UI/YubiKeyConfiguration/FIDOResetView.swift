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
    
    @Environment(\.dismiss) private var dismiss
    @StateObject var model = FIDOResetViewModel()
    
    @State var presentConfirmAlert = false
    @State var presentErrorAlert = false
    @State var progress = 0.0
    @State var messageText = "Reset all FIDO accounts stored on YubiKey, make sure they are not in use anywhere before doing this."
    @State var enableResetButton = true
    @State var errorMessage: String? = nil
    @State var opacity = 1.0

    var body: some View {
        SettingsView(image: Image(systemName: "exclamationmark.triangle").foregroundColor(.red)) {
            Text("Reset FIDO application").font(.headline).opacity(opacity)
            ProgressView(value: progress, total: 4.0).opacity(opacity)
            Text(messageText).multilineTextAlignment(.center)
        } buttons: {
            SettingsButton("Reset Yubikey") {
                presentConfirmAlert.toggle()
            }
            .disabled(!enableResetButton)
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
        .alert(errorMessage ?? "Unknown error", isPresented: $presentErrorAlert, actions: {
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
                self.messageText = "Reset all FIDO accounts stored on YubiKey, make sure they are not in use anywhere before doing this."
            case .waitingForKeyRemove:
                self.enableResetButton = false
                self.progress = 1.0
                self.messageText = "Remove your YubiKey to proceed."
            case .waitingForKeyReinsert:
                self.enableResetButton = false
                self.progress = 2.0
                self.messageText = "Re-insert your Yubikey."
            case .waitingForKeyTouch:
                self.progress = 3.0
                self.enableResetButton = false
                self.messageText = "Touch YubiKey to finish resetting the FIDO application."
            case .success:
                self.progress = 4.0
                self.opacity = 0.5
                self.enableResetButton = false
                self.messageText = "Your Yubikey has been reset to factory defaults."
            case .error(let error):
                self.enableResetButton = true
                self.presentErrorAlert = true
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
