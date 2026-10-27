/*
 * Copyright (C) Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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

struct EditView: View {

    @Binding var showEditing: Bool

    let viewModel: MainViewModel
    let account: Account

    private enum Field {
        case issuer, accountName
    }

    @State private var issuer: String
    @State private var accountName: String
    @State private var showEmptyNameAlert = false
    @FocusState private var focusedField: Field?

    init(account: Account, viewModel: MainViewModel, showEditing: Binding<Bool> ) {
        self.account = account
        self.viewModel = viewModel
        _showEditing = showEditing
        _issuer = State(initialValue: account.credential.issuer ?? "")
        _accountName = State(initialValue: account.credential.accountName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(String(localized: "Issuer", comment: "Rename account field")) {
                        TextField(String(localized: "Issuer", comment: "Rename account field"), text: $issuer)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .issuer)
                    }
                    LabeledContent(String(localized: "Account name", comment: "Rename account field")) {
                        TextField(String(localized: "Account name", comment: "Rename account field"), text: $accountName)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .focused($focusedField, equals: .accountName)
                    }
                }
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .onSubmit {
                    if focusedField == .issuer {
                        focusedField = .accountName
                    } else {
                        save()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "Rename", comment: "Rename account navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CancelButton { showEditing = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(String(localized: "Save")) { save() }
                }
            }
            .alert(String(localized: "Account not set", comment: "Rename credential alert"), isPresented: $showEmptyNameAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(String(localized: "Account name can not be empty", comment: "Rename credential alert"))
            }
            .onAppear {
                focusedField = .accountName
            }
        }
    }

    private func save() {
        guard !accountName.isEmpty else {
            showEmptyNameAlert = true
            return
        }
        viewModel.renameAccount(account, issuer: issuer, accountName: accountName) {}
        showEditing = false
    }
}
