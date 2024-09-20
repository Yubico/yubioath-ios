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
    
    @State var error: Error? = nil
    
    @State var showSetButton = true
    @State var showChangeButton = false
    @State var showRemoveButton = false
    
    func areButtonsDisabled() -> Bool {
        model.state == .unknown || model.state.isError() || model.isProcessing
    }

    var body: some View {
        SettingsView(image: Image(systemName: "key")) {
            Text("OATH password protection").font(.headline)
            Text("For additional security and to prevent unauthorized access the YubiKey can be password protected.")
                .font(.callout)
                .multilineTextAlignment(.center)
        } buttons: {
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
        .navigationBarTitle(Text("OATH passwords"), displayMode: .inline)
        .sheet(isPresented: $presentSetPassword) {
            OATHSetChangePasswordView(type: .set)
        }
        .sheet(isPresented: $presentChangePassword) {
            OATHSetChangePasswordView(type: .change)
        }
        .sheet(isPresented: $presentRemovePassword) {
            OATHSetChangePasswordView(type: .remove)
        }
        .alert(error?.localizedDescription ?? String(localized: "Unknown error"), isPresented: $presentErrorAlert, actions: {
            Button(role: .cancel) {
                error = nil
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
                case .notSet, .didRemove:
                    self.showSetButton = true
                    self.showChangeButton = false
                    self.showRemoveButton = false
                case .set, .didSet, .didChange:
                    self.showSetButton = false
                    self.showChangeButton = true
                    self.showRemoveButton = true
                case .error(let error):
                    guard presentSetPassword == false
                            && presentChangePassword == false
                            && presentRemovePassword == false
                    else { return }
                    presentErrorAlert = true
                    self.error = error
                case .keyRemoved:
                    dismiss()
                }
            }
        }
        .environmentObject(model)
    }
}


struct OATHSetChangePasswordView: View {
    
    enum Action { case set, change, remove }
    let type: Action
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) var displayScale
    
    @EnvironmentObject var model: OATHPasswordViewModel
    @FocusState private var focusedField: FocusedField?

    enum FocusedField {
        case currentPassword, newPassword, repeatedPassword
    }
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var repeatedPassword: String = ""
    
    @State private var presentErrorAlert = false
    @State private var errorMessage: String? = nil
    
    var navBarTitle: String {
        switch self.type {
        case .set:
            return String(localized: "Set password")
        case .change:
            return String(localized: "Change password")
        case .remove:
            return String(localized: "Remove password")
        }
    }
    
    var buttonTitle: String {
        switch self.type {
        case .set:
            return String(localized: "Set")
        case .change:
            return String(localized: "Change")
        case .remove:
            return String(localized: "Remove")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 0) {
                    if type == .change || type == .remove {
                        HStack {
                            Text(type == .remove ? String(localized: "Password", comment: "Enter password in secure field to remove password.") : String(localized: "Current", comment: "Enter current password in secure field to change password.")).frame(maxWidth: 100, alignment: .leading).padding()
                            SecureField("enter current password", text: $currentPassword).submitLabel(.next).focused($focusedField, equals: .currentPassword)
                        }
                        Color(.separator)
                            .frame(height: 1.0 / displayScale)
                            .frame(maxWidth: .infinity)
                            .padding(0)
                    }
                    if type != .remove {
                        HStack {
                            Text(String(localized: "New", comment: "Enter new password in secure field.")).frame(maxWidth: 100, alignment: .leading).padding()
                            SecureField("enter password", text: $newPassword).submitLabel(.next).focused($focusedField, equals: .newPassword)
                        }
                        Color(.separator)
                            .frame(height: 1.0 / displayScale)
                            .frame(maxWidth: .infinity)
                            .padding(0)
                        HStack {
                            Text(String(localized: "Verify", comment: "Re-enter new password in secure field.")).frame(maxWidth: 100, alignment: .leading).padding()
                            SecureField("re-enter password", text: $repeatedPassword).submitLabel(.return).focused($focusedField, equals: .repeatedPassword)
                        }
                    }
                }
                .onSubmit {
                    if type == .remove {
                        handleInput()
                    } else {
                        if focusedField == .currentPassword {
                            focusedField = .newPassword
                        } else if focusedField == .newPassword {
                            focusedField = .repeatedPassword
                        } else {
                            focusedField = nil
                            handleInput()
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.top, 25)
                .padding(.horizontal, 15)
                .padding(.bottom, 5)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitle(self.navBarTitle, displayMode: .inline)
            .navigationBarItems(leading: Button(action: { dismiss() }, label: { Text("Cancel") }))
            .navigationBarItems(trailing: Button(action: {
                handleInput()
            }, label: { Text(self.buttonTitle) })
            )
            .onAppear {
                focusedField = type == .set ? .newPassword : .currentPassword
            }
            .onChange(of: model.state) { state in
                switch model.state {
                case .error(let error):
                    self.errorMessage = error.localizedDescription
                    self.currentPassword = ""
                    self.newPassword = ""
                    self.repeatedPassword = ""
                    presentErrorAlert = true
                case .didSet, .didChange, .didRemove:
                    dismiss()
                default: break
                }
            }
            .alert(errorMessage ?? String(localized: "Unknown error"), isPresented: $presentErrorAlert, actions: {
                Button(role: .cancel) {
                    errorMessage = nil
                    if model.state.isFatalError() {
                        dismiss()
                    } else {
                        focusedField = type == .set ? .newPassword : .currentPassword
                    }
                } label: {
                    Text("OK")
                }
            })
        }
    }
    
    private func handleInput() {
        switch type {
        case .set:
            model.setPassword(newPassword, repeated: repeatedPassword)
        case .change:
            model.changePassword(old: currentPassword, new: newPassword, repeated: repeatedPassword)
        case .remove:
            model.removePassword(current: currentPassword)
        }
    }
}

