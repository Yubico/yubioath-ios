//
//  OATHPasswordView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-22.
//  Copyright © 2024 Yubico. All rights reserved.
//


import SwiftUI

struct OATHPasswordView: View {
    
    @StateObject var model = OATHPasswordViewModel()
    @Environment(\.dismiss) private var dismiss

    @State var presentSetPassword = false
    @State var presentChangePassword = false
    @State var presentRemovePassword = false
    @State var presentErrorAlert = false
    @State var errorMessage: String? = nil
    
    @State var showSetButton = true
    @State var showChangeButton = false
    @State var showRemoveButton = false
    
    @State var password: String = ""
    @State var newPassword: String = ""
    @State var repeatedPassword: String = ""
    
    func areButtonsDisabled() -> Bool {
        model.state == .unknown || model.state.isError() || model.isProcessing
    }
    
    func clearPasswords() {
        password = ""
        newPassword = ""
        repeatedPassword = ""
    }

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    Image(systemName: "key")
                        .font(.system(size:50.0))
                        .bold()
                        .foregroundColor(Color(.yubiBlue))
                        .rotationEffect(Angle(degrees: 90))
                        .accessibilityHidden(true)
                    Text("Manage OATH passwords").font(.headline)
                    Text("Reset all accounts stored on YubiKey, make sure they are not in use anywhere before doing this.")
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
                if showSetButton {
                    SettingsButton("Set password") {
                        presentSetPassword.toggle()
                    }.disabled(areButtonsDisabled())
                }
                if showChangeButton {
                    SettingsButton("Change password") {
                        presentChangePassword.toggle()
                    }.disabled(areButtonsDisabled())
                }
                if showRemoveButton {
                    SettingsButton("Remove password") {
                        presentRemovePassword.toggle()
                    }.disabled(areButtonsDisabled())
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .padding(20)
            .opacity(model.state.isError() ? 0.5 : 1.0)
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitle(Text("OATH passwords"), displayMode: .inline)
        
        .alert("Set password", isPresented: $presentSetPassword) {
            SecureField("Password", text: $newPassword)
            SecureField("Repeat new password", text: $repeatedPassword)
            Button("OK") {
                guard newPassword == repeatedPassword else {
                    errorMessage = "Passwords do not match"
                    presentErrorAlert = true
                    clearPasswords()
                    return
                }
                model.setPassword(newPassword)
                clearPasswords()
            }
        } message: {
            Text("Protect this YubiKey with a password.")
        }
        .alert("Change password", isPresented: $presentChangePassword) {
            SecureField("Current password", text: $password)
            SecureField("New Password", text: $newPassword)
            SecureField("Repeat new password", text: $repeatedPassword)
            Button("OK") {
                guard newPassword == repeatedPassword else {
                    errorMessage = "New passwords do not match"
                    presentErrorAlert = true
                    clearPasswords()
                    return
                }
                model.changePassword(old: password, new: newPassword)
                clearPasswords()
            }
            Button("Cancel", role: .cancel, action: { clearPasswords() })
        } message: {
            Text("Change the password for this YubiKey. \(newPassword)")
        }
        .alert("Remove password", isPresented: $presentRemovePassword) {
            SecureField("Current password", text: $password)
            Button("OK", role: .destructive) {
                model.removePassword(current: password)
                clearPasswords()
                presentRemovePassword.toggle()
            }
            Button("Cancel", role: .cancel, action: { clearPasswords() })
        } message: {
            Text("Remove the password for this YubiKey.")
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
            withAnimation {
                switch state {
                case .unknown:
                    self.showSetButton = true
                    self.showChangeButton = false
                    self.showRemoveButton = false
                case .notSet:
                    self.showSetButton = true
                    self.showChangeButton = false
                    self.showRemoveButton = false
                case .set:
                    self.showSetButton = false
                    self.showChangeButton = true
                    self.showRemoveButton = true
                case .error(let error):
                    presentErrorAlert = true
                    self.errorMessage = error.localizedDescription
                }
            }
        }
        .onChange(of: model.invalidPassword) { invalidPassword in
            if invalidPassword {
                self.errorMessage = "Wrong password"
                self.presentErrorAlert = true
            }
        }
    }
}
