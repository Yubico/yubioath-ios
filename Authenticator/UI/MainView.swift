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

struct MainView: View {
    
    @StateObject var model = MainViewModel()
    @State var showAccountDetails: AccountDetailsData? = nil
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
                        Button(action: { }) {
                            Label("Add account", systemImage: "qrcode")
                        }
                        Button(action: { }) {
                            Label("Configuration", systemImage: "switch.2")
                        }
                        Button(action: { }) {
                            Label("About", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Label("Menu", systemImage: "ellipsis.circle")
                    }
                }
            }
            .navigationTitle(model.accountsLoaded ? "Accounts" : "")
        }.overlay {
            if showAccountDetails != nil {
                AccountDetailsView(data: $showAccountDetails)
            }
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
        .environmentObject(model)
    }
}
