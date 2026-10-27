//
//  OATHPasswordView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-22.
//  Copyright © 2024 Yubico. All rights reserved.
//  Copyright © 2026 Kenzi Voyer.
//


import SwiftUI

struct OATHPasswordView: View {
    
    @State var model = OATHPasswordViewModel()
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
        SettingsView(image: Image(systemName: "lock.shield"), imageColor: Color(.systemPurple)) {
            Text("OATH password").font(.title2).bold()
            Text("To prevent unauthorized access the OATH application can be protected by a password.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
        } buttons: {
            if showSetButton {
                SettingsButton(String(localized: "Set password")) {
                    presentSetPassword.toggle()
                }.disabled(areButtonsDisabled())
            }
            if showChangeButton {
                SettingsButton(String(localized: "Change password")) {
                    presentChangePassword.toggle()
                }.disabled(areButtonsDisabled())
            }
            if showRemoveButton {
                SettingsButton(String(localized: "Remove password")) {
                    presentRemovePassword.toggle()
                }.disabled(areButtonsDisabled())
            }
        }
        .navigationTitle(Text("OATH passwords"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $presentSetPassword) {
            OATHSetChangePasswordView(type: .set)
        }
        .sheet(isPresented: $presentChangePassword) {
            OATHSetChangePasswordView(type: .change)
        }
        .sheet(isPresented: $presentRemovePassword) {
            OATHSetChangePasswordView(type: .remove)
        }
        .errorAlert(error: $error) { dismiss() }
        .onChange(of: model.state) { _, state in
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
                    self.showRemoveButton = !model.isFipsKey
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
        .onAppear {
            model.load()
        }
        .environment(model)
    }
}


struct OATHSetChangePasswordView: View {
    
    enum Action { case set, change, remove }
    let type: Action
    
    @Environment(\.dismiss) private var dismiss
    
    @Environment(OATHPasswordViewModel.self) var model
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
    
    var currentPasswordLabel: String {
        type == .remove ? String(localized: "Password", comment: "Enter password in secure field to remove password.") : String(localized: "Current", comment: "Enter current password in secure field to change password.")
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
        NavigationStack {
            Form {
                Section {
                    if type == .change || type == .remove {
                        LabeledContent {
                            SecureField(text: $currentPassword, prompt: Text("enter current password")) {
                                Text(currentPasswordLabel)
                            }
                            .submitLabel(.next)
                            .focused($focusedField, equals: .currentPassword)
                        } label: {
                            Text(currentPasswordLabel)
                        }
                    }
                    if type != .remove {
                        LabeledContent {
                            SecureField(text: $newPassword, prompt: Text("enter password")) {
                                Text(String(localized: "New", comment: "Enter new password in secure field."))
                            }
                            .submitLabel(.next)
                            .focused($focusedField, equals: .newPassword)
                        } label: {
                            Text(String(localized: "New", comment: "Enter new password in secure field."))
                        }
                        LabeledContent {
                            SecureField(text: $repeatedPassword, prompt: Text("re-enter password")) {
                                Text(String(localized: "Verify", comment: "Re-enter new password in secure field."))
                            }
                            .submitLabel(.return)
                            .focused($focusedField, equals: .repeatedPassword)
                        } label: {
                            Text(String(localized: "Verify", comment: "Re-enter new password in secure field."))
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
            }
            .formStyle(.grouped)
            .navigationTitle(self.navBarTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(self.buttonTitle) { handleInput() }
                }
            }
            .onAppear {
                focusedField = type == .set ? .newPassword : .currentPassword
            }
            .onChange(of: model.state) { _, state in
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

