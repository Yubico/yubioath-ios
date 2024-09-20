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
    
    @State var error: Error? = nil
    
    @State var showSetButton = true
    @State var showChangeButton = false
    
    func areButtonsDisabled() -> Bool {
        model.state == .unknown || model.state.isFatalError() || model.isProcessing || model.state.isBlocked() || model.state.isPermanentlyBlocked()
    }

    var body: some View {
        SettingsView(image: Image(systemName: "key")) {
            Text("FIDO PIN protection").font(.headline)
            Text("For additional security and to prevent unauthorized access the FIDO application can be protected by a PIN.")
                .font(.callout)
                .multilineTextAlignment(.center)
            
            if model.state.isBlocked() {
                Text("PIN is temporary blocked. Remove and reinsert YubiKey to try again.")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .bold()
                    .multilineTextAlignment(.center)
            }
            if model.state.isPermanentlyBlocked() {
                Text("PIN is permanently blocked. Factory reset FIDO application to continue.")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .bold()
                    .multilineTextAlignment(.center)
            }
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
        .sheet(isPresented: $presentSetPIN) {
            FIDOSetChangePINView(type: .set)
        }
        .sheet(isPresented: $presentChangePIN) {
            FIDOSetChangePINView(type: .change)
        }
        .alert(error?.localizedDescription ?? String(localized: "Unknown error"), isPresented: $presentErrorAlert, actions: {
            Button(role: .cancel) {
                error = nil
                if model.state.isFatalError() {
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
        .environmentObject(model)
    }
    
    func updateState() {
        withAnimation {
            switch model.state {
            case .unknown:
                break
            case .notSet:
                self.showSetButton = true
                self.showChangeButton = false
            case .set, .didSet, .didChange:
                self.showSetButton = false
                self.showChangeButton = true
            case .error(let error):
                guard presentSetPIN == false && presentChangePIN == false else { return }
                presentErrorAlert = true
                self.error = error
            case .keyRemoved:
                dismiss()
            }
        }
    }
}

struct FIDOSetChangePINView: View {
    
    enum Action { case set, change }
    var type: Action
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) var displayScale
    
    @EnvironmentObject var model: FIDOPINViewModel
    @FocusState private var focusedField: FocusedField?

    enum FocusedField {
        case currentPIN, newPIN, repeatedPIN
    }
    
    @State private var currentPIN: String = ""
    @State private var newPIN: String = ""
    @State private var repeatedPIN: String = ""
    
    @State private var presentErrorAlert = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 0) {
                    if type == .change {
                        HStack {
                            Text("Current PIN").frame(maxWidth: 100, alignment: .leading).padding()
                            SecureField("enter current PIN", text: $currentPIN).submitLabel(.next).focused($focusedField, equals: .currentPIN)
                            
                        }
                        Color(.separator)
                            .frame(height: 1.0 / displayScale)
                            .frame(maxWidth: .infinity)
                            .padding(0)
                    }
                    HStack {
                        Text("New").frame(maxWidth: 100, alignment: .leading).padding()
                        SecureField("enter PIN", text: $newPIN).submitLabel(.next).focused($focusedField, equals: .newPIN)

                    }
                    Color(.separator)
                        .frame(height: 1.0 / displayScale)
                        .frame(maxWidth: .infinity)
                        .padding(0)
                    HStack {
                        Text("Verify").frame(maxWidth: 100, alignment: .leading).padding()
                        SecureField("re-enter PIN", text: $repeatedPIN).submitLabel(.return).focused($focusedField, equals: .repeatedPIN)
                    }
                }
                .onSubmit {
                    if focusedField == .currentPIN {
                        focusedField = .newPIN
                    } else if focusedField == .newPIN {
                        focusedField = .repeatedPIN
                    } else {
                        focusedField = nil
                        setNewPin()
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
                .padding(.top, 25)
                .padding(.horizontal, 15)
                .padding(.bottom, 5)

                Text("\(model.pincomplexity ? "A PIN must be at least \(model.minPinLength) characters long, contain at least 2 unique characters, and not be a commonly used PIN, like \"123456\". It may contain letters, numbers and special characters." : "A PIN must be at least \(model.minPinLength) characters long and may contain letters, numbers and special characters.")")
                    .font(.subheadline)
                    .foregroundStyle(Color(.secondaryLabel))
                    .padding(.horizontal, 25)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .navigationBarTitle(type == .set ? String(localized: "Set PIN") : String(localized: "Change PIN"), displayMode: .inline)
            .navigationBarItems(leading: Button(action: { dismiss() }, label: { Text("Cancel") }))
            .navigationBarItems(trailing: Button(action: {
                setNewPin()
            }, label: { Text("Set") })
            )
            .onAppear {
                focusedField = type == .set ? .newPIN : .currentPIN
            }
            .onChange(of: model.state) { state in
                switch model.state {
                case .error(let error):
                    self.errorMessage = error.localizedDescription
                    self.currentPIN = ""
                    self.newPIN = ""
                    self.repeatedPIN = ""
                    presentErrorAlert = true
                case .didSet, .didChange:
                    dismiss()
                default: break
                }
            }
            .alert(errorMessage ?? String(localized: "Unknown error"), isPresented: $presentErrorAlert, actions: {
                Button(role: .cancel) {
                    errorMessage = nil
                    if model.state.isFatalError() {
                        dismiss()
                    }
                } label: {
                    Text("OK")
                }
            })
        }
    }
    
    private func presentValidationError(_ message: String) {
        errorMessage = message
        presentErrorAlert.toggle()
        currentPIN = ""
        newPIN = ""
        repeatedPIN = ""
        focusedField = type == .set ? .newPIN : .currentPIN
    }
    
    private func setNewPin() {
        guard newPIN == repeatedPIN else {
            presentValidationError(String(localized: "PINs do not match.", comment: "Set PIN view validation error"))
            return
        }
        guard newPIN.count >= model.minPinLength else {
            presentValidationError(String(localized: "PIN should be at least \(model.minPinLength) characters long."))
            return
        }
        if type == .set {
            model.setPIN(newPIN)
        } else {
            model.changePIN(old: currentPIN, new: newPIN)
        }
    }
}
