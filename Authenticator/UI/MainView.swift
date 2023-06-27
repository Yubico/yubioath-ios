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
    
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var toastPresenter: ToastPresenter
    
    @StateObject var model = MainViewModel()
    @State var showAccountDetails: AccountDetailsData? = nil
    @State var showAddAccount: Bool = false
    @State var addAccountCancellable: AnyCancellable?
    @State var addAccountSubject = PassthroughSubject<(YKFOATHCredentialTemplate?, Bool), Never>()
    @State var showConfiguration: Bool = false
    @State var showAbout: Bool = false
    @State var password: String = ""
    @State var searchText: String = ""
    @State var didEnterBackground = true
    @State var otp: String? = nil
    @State var oathURL: URL? = nil
    
    var body: some View {
        NavigationView {
            GeometryReader { reader in
                List {
                    if let otp {
                        Section(header: Text("Yubico OTP").frame(maxWidth: .infinity, alignment: .leading).font(.title3.bold()).foregroundColor(Color("ListSectionHeaderColor"))) {
                            YubiOtpRowView(otp: otp)
                        }
                    }
                    if !model.accountsLoaded {
                        ListStatusView(image: Image("yubikey"), message: "Insert YubiKey or pull down to activate NFC", height: reader.size.height)
                    } else if !searchText.isEmpty {
                        if searchResults.count > 0 {
                            ForEach(searchResults, id: \.id) { account in
                                AccountRowView(account: account, showAccountDetails: $showAccountDetails)
                            }
                        } else {
                            ListStatusView(image: Image(systemName: "person.crop.circle.badge.questionmark"), message: "No matching accounts on YubiKey", height: reader.size.height)
                        }
                    } else if model.pinnedAccounts.count > 0 {
                        Section(header: Text("Pinned").frame(maxWidth: .infinity, alignment: .leading).font(.title3.bold()).foregroundColor(Color("ListSectionHeaderColor"))) {
                            ForEach(model.pinnedAccounts, id: \.id) { account in
                                AccountRowView(account: account, showAccountDetails: $showAccountDetails)
                            }
                        }
                        if model.otherAccounts.count > 0 {
                            Section(header: Text("Other").frame(maxWidth: .infinity, alignment: .leading).font(.title3.bold()).foregroundColor(Color("ListSectionHeaderColor"))) {
                                ForEach(model.otherAccounts, id: \.id) { account in
                                    AccountRowView(account: account, showAccountDetails: $showAccountDetails)
                                }
                            }
                        }
                    } else if model.accounts.count > 0 && otp != nil {
                        Section(header: Text("Accounts").frame(maxWidth: .infinity, alignment: .leading).font(.title3.bold()).foregroundColor(Color("ListSectionHeaderColor"))) {
                            ForEach(model.otherAccounts, id: \.id) { account in
                                AccountRowView(account: account, showAccountDetails: $showAccountDetails)
                            }
                        }
                    } else if model.accounts.count > 0 {
                        ForEach(model.accounts, id: \.id) { account in
                            AccountRowView(account: account, showAccountDetails: $showAccountDetails)
                        }
                    } else {
                        ListStatusView(image: Image(systemName: "person.crop.circle"), message: "No accounts on YubiKey", height: reader.size.height)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search")
            .autocorrectionDisabled(true)
            .keyboardType(.asciiCapable)
            .listStyle(.inset)
            .refreshable {
                otp = nil
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
                        .disabled(!YubiKitDeviceCapabilities.supportsISO7816NFCTags && !model.isKeyPluggedIn)
                        Button(action: { showConfiguration.toggle() }) {
                            Label("Configuration", systemImage: "switch.2")
                        }
                        .disabled(!YubiKitDeviceCapabilities.supportsISO7816NFCTags && !model.isKeyPluggedIn)
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
            AddAccountView(showAddCredential: $showAddAccount, accountSubject: addAccountSubject, oathURL: oathURL)
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
        .confirmationDialog("Save password?", isPresented: $model.presentPasswordSaveType) {
            Button("Save password") { model.passwordSaveType.send(.some(.save)) }
            let authenticationType = PasswordPreferences.evaluatedAuthenticationType()
            Button("Save and protect with \(authenticationType.title)") { model.passwordSaveType.send(.some(.lock)) }
            Button("Never for this YubiKey") { model.passwordSaveType.send(.some(.never)) }
            Button("Not now" , role: .cancel) { model.passwordSaveType.send(nil) }
        }
        .errorAlert(error: $model.error)
        .onAppear {
            if ApplicationSettingsViewModel().isNFCOnAppLaunchEnabled {
                model.updateAccountsOverNFC()
            }
            addAccountCancellable = addAccountSubject.sink { (template, requiresTouch) in
                oathURL = nil
                if let template {
                    model.addAccount(template, requiresTouch: requiresTouch)
                }
            }
        }
        .onOpenURL(perform: { url in
            guard url.scheme == "otpauth" else { return }
            if showConfiguration { showConfiguration.toggle() }
            if showAbout { showAbout.toggle() }
            oathURL = url
            showAddAccount.toggle()
            print("👾 handle add OATH account \(url)")
        })
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb, perform: { userActivity in
            guard let otp = userActivity.webpageURL?.yubiOTP else { return }
            if showConfiguration { showConfiguration.toggle() }
            if showAbout { showAbout.toggle() }
            self.otp = otp
            if ApplicationSettingsViewModel().isNFCOnOTPLaunchEnabled {
                model.updateAccountsOverNFC()
            }
        })
        .onChange(of: otp) { otp in
            if let otp, SettingsConfig.isCopyOTPEnabled {
                toastPresenter.copyToClipboard(otp)
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active && didEnterBackground {
                didEnterBackground = false
                model.start() // This is called when app becomes active
            } else if phase == .background {
                didEnterBackground = true
                model.stop()
            }
        }
        .onChange(of: model.showTouchToast) { showToast in
            if showToast {
                toastPresenter.toast(message: "Touch your YubiKey")
            }
        }
        .environmentObject(model)
    }
    
    var searchResults: [Account] {
        if searchText.isEmpty {
            return [Account]()
        } else {
            return model.accounts.filter { $0.title.lowercased().contains(searchText.lowercased()) ||
                $0.subTitle?.lowercased().contains(searchText.lowercased()) == true }
        }
    }
}


extension URL {
    
    var yubiOTP: String? {
        if self.scheme == "https" && self.host == "my.yubico.com" {
            var otp: String
            let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
            if let fragment = components?.fragment {
                otp = fragment
            } else {
                otp = self.lastPathComponent
            }
            return otp
        } else {
            return nil
        }
    }
}
