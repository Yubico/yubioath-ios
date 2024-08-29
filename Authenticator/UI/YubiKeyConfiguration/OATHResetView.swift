//
//  OATHResetView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-20.
//  Copyright © 2024 Yubico. All rights reserved.
//

import SwiftUI

struct OATHResetView: View {
    
    @StateObject var model = ResetOATHViewModel()
    @State var presentConfirmAlert = false
    @State var presentErrorAlert = false
    @State var keyHasBeenReset = false
    @State var errorMessage: String? = nil

    var body: some View {
        SettingsView(image: Image(systemName: "exclamationmark.triangle").foregroundColor(.red)) {
            Text(keyHasBeenReset ? "YubiKey has been reset" : "Reset OATH application").font(.headline)
            Text("Reset all accounts stored on YubiKey, make sure they are not in use anywhere before doing this.")
                .multilineTextAlignment(.center)
                .opacity(keyHasBeenReset ? 0.2 : 1.0)
        } buttons: {
            SettingsButton("Reset Yubikey") {
                presentConfirmAlert.toggle()
            }
            .disabled(keyHasBeenReset)
        }
        .navigationBarTitle(Text("Reset OATH"), displayMode: .inline)
        .alert("Confirm OATH reset", isPresented: $presentConfirmAlert, presenting: model, actions: { model in
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
        .background(Color(.systemGroupedBackground))
    }
}
