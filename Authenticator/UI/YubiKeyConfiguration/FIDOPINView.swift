//
//  OATHPasswordView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-22.
//  Copyright © 2024 Yubico. All rights reserved.
//


import SwiftUI

struct FIDOPINView: View {
    
    @StateObject var model = FIDOPINViewModel()
    @Environment(\.dismiss) private var dismiss

    @State var presentSetPIN = false
    @State var presentChangePIN = false
    @State var presentErrorAlert = false
    @State var errorMessage: String? = nil
    
    @State var showSetButton = true
    @State var showChangeButton = false
    @State var pinComplexity = false
    
    @State var pin: String = ""
    @State var newPIN: String = ""
    @State var repeatedPIN: String = ""
    
    func areButtonsDisabled() -> Bool {
        model.state == .unknown || model.state.isError() || model.isProcessing
    }
    
    func clearState() {
        pin = ""
        newPIN = ""
        repeatedPIN = ""
    }

    var body: some View {
        SettingsView(image: Image(systemName: "key")) {
            Text("FIDO PIN protection").font(.headline)
            Text("For additional security and to prevent unauthorized access the YubiKey can be protected by a PIN.")
                .font(.callout)
                .multilineTextAlignment(.center)
            Text("\(pinComplexity ? "PIN has to be at least \(model.minPinLength) digits and should not be easily guessed" : "PIN has to be at least \(model.minPinLength) digits")")
                .font(.callout)
                .multilineTextAlignment(.center)
        } buttons: {
            if showSetButton {
                SettingsButton("Set PIN") {
                    presentSetPIN.toggle()
                }.disabled(areButtonsDisabled())
            }
            if showChangeButton {
                SettingsButton("Change PIN") {
                    presentChangePIN.toggle()
                }.disabled(areButtonsDisabled())
            }
        }
        .navigationBarTitle(Text("FIDO PIN"), displayMode: .inline)
        .alert("Set PIN", isPresented: $presentSetPIN) {
            SecureField("PIN", text: $newPIN)
            SecureField("Repeat new PIN", text: $repeatedPIN)
            Button("OK") {
                guard newPIN == repeatedPIN else {
                    errorMessage = "PIN codes do not match"
                    presentErrorAlert = true
                    clearState()
                    return
                }
                model.setPIN(newPIN)
                clearState()
            }
        } message: {
            Text("Protect this YubiKey with a PIN code.")
        }
        .alert("Change PIN", isPresented: $presentChangePIN) {
            SecureField("Current PIN", text: $pin)
            SecureField("New PIN", text: $newPIN)
            SecureField("Repeat new PIN", text: $repeatedPIN)
            Button("OK") {
                guard newPIN == repeatedPIN else {
                    errorMessage = "New PIN codes do not match"
                    presentErrorAlert = true
                    clearState()
                    return
                }
                model.changePIN(old: pin, new: newPIN)
                clearState()
            }
            Button("Cancel", role: .cancel, action: { clearState() })
        } message: {
            Text("Change the PIN for this YubiKey. \(newPIN)")
        }
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
        .onChange(of: model.state) { state in
            updateState()
        }
        .onAppear {
            updateState()
        }
        .onChange(of: model.pincomplexity) { pinComplexity in
            withAnimation {
                self.pinComplexity = pinComplexity
            }
        }
        .onChange(of: model.invalidPIN) { invalidPassword in
            if invalidPassword {
                self.errorMessage = "Wrong PIN"
                self.presentErrorAlert = true
            }
        }
    }
    
    func updateState() {
        withAnimation {
            switch model.state {
            case .unknown:
                self.showSetButton = true
                self.showChangeButton = false
            case .notSet:
                self.showSetButton = true
                self.showChangeButton = false
            case .set:
                self.showSetButton = false
                self.showChangeButton = true
            case .error(let error):
                presentErrorAlert = true
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
