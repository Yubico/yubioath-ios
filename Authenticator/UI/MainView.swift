/*
 * Copyright (C) Yubico.
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
import Combine

struct MainView: View {
    
    @StateObject var model = MainViewModel()
    @State var showAccountDetails: AccountDetailsData? = nil
    @State var showAddAccount: Bool = false
    @State var addAccountCancellable: AnyCancellable?
    @State var addAccountSubject = PassthroughSubject<(YKFOATHCredentialTemplate, Bool), Never>()
    @State var showConfiguration: Bool = false
    @State var showAbout: Bool = false
    @State var password: String = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(model.accounts, id: \.id) { account in
                    AccountRowView(account: account, showAccountDetails: $showAccountDetails)
                }
            }
            .listStyle(.inset)
            .refreshable {
                model.updateAccountsOverNFC()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !model.accountsLoaded {
                        Image("NavbarLogo")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 20)
                            .foregroundColor(Color("YubiGreen"))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showAddAccount.toggle() }) {
                            Label("Add account", systemImage: "qrcode")
                        }
                        Button(action: { showConfiguration.toggle() }) {
                            Label("Configuration", systemImage: "switch.2")
                        }
                        Button(action: { showAbout.toggle() }) {
                            Label("About", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Label("Menu", systemImage: "ellipsis.circle")
                    }
                }
            }
            .navigationTitle(model.accountsLoaded ? "Accounts" : "")
        }
        .overlay {
            if showAccountDetails != nil {
                AccountDetailsView(data: $showAccountDetails)
            }
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountView(showAddCredential: $showAddAccount, accountSubject: addAccountSubject)
        }
        .fullScreenCover(isPresented: $showConfiguration) {
            ConfigurationView(showConfiguration: $showConfiguration)
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutView(showHelp: $showAbout)
        }
        .alert("Enter password", isPresented: $model.presentPasswordEntry) {
            SecureField("Password", text: $password)
            Button("Cancel", role: .cancel) { password = ""; print("👾 Cancel") }
            Button("Ok") {
                model.password.send(password)
                password = ""
                print("👾 Ok")
            }
        } message: {
            Text(model.passwordEntryMessage)
        }
        .errorAlert(error: $model.error)
        .onAppear {
            if ApplicationSettingsViewModel().isNFCOnAppLaunchEnabled {
                model.updateAccountsOverNFC()
            }
            addAccountCancellable = addAccountSubject.sink { (template, requiresTouch) in
                model.addAccount(template, requiresTouch: requiresTouch)
            }
        }
        .environmentObject(model)
    }
}
