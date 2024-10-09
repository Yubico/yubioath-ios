/*
 * Copyright (C) 2022 Yubico.
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

struct ConfigurationView: View {
    @StateObject var model = ConfigurationViewModel()
    @Binding var showConfiguration: Bool
    @State var showInsertYubiKey: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                if model.deviceInfo == nil {
                    VStack(alignment: .center) {
                        Image("yubikey")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundStyle(.secondary)
                            .padding(15)
                        Text("Insert YubiKey or pull down to activate NFC")
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    .listRowBackground(Color("SheetBackgroundColor"))
                }
                
                if let deviceInfo = model.deviceInfo {
                    Section(" ") {
                        VStack(alignment: .center) {
                            if let image = deviceInfo.deviceImage {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 150, height: 150)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        if let deviceInfo = model.deviceInfo {
                            HStack {
                                ListIconView(image: Image("yubikey"), color: Color(.systemGray))
                                Text("Device type")
                                Spacer()
                                Text(deviceInfo.deviceName).foregroundStyle(.secondary)
                            }
                            HStack {
                                ListIconView(image: Image(systemName: "number"), color: Color(.systemGray), padding: 7)
                                Text("Serial number")
                                Spacer()
                                Text(String(deviceInfo.serialNumber)).foregroundStyle(.secondary)
                            }
                            HStack {
                                ListIconView(image: Image(systemName: "cpu"), color: Color(.systemGray), padding: 5)
                                Text("Firmware version")
                                Spacer()
                                Text(deviceInfo.version.description).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("GENERAL") {
                    NavigationLink {
                        OTPConfigurationView()
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle("Toggle One-Time Password")
                            .background(Color("SheetBackgroundColor"))
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "ellipsis.rectangle"), color: Color(.systemBlue))
                        Text("Toggle One-Time Password")
                    }
                    NavigationLink {
                        NFCSettingsView()
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle("NFC settings")
                            .background(Color("SheetBackgroundColor"))
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "dot.radiowaves.left.and.right"), color: Color(.systemBlue))
                        Text("NFC settings")
                    }
                }
                Section("OATH") {
                    NavigationLink {
                        OATHPasswordView()
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "lock.shield"), color: Color(.systemPurple))
                        Text("Manage password")
                    }
                    NavigationLink {
                        OATHSavedPasswordsView()
                    } label: {
                        ListIconView(image: Image(systemName: "xmark.circle"), color: Color(.systemRed), padding: 5)
                        Text("Clear saved passwords")
                    }
                    NavigationLink {
                        OATHResetView()
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "trash"), color: Color(.systemRed), padding: 5)
                        Text("Reset OATH application")
                    }
                }
                Section("FIDO") {
                    NavigationLink {
                        FIDOPINView()
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "lock.shield"), color: Color(.systemPurple))
                        Text("Manage PIN")
                    }
                    NavigationLink {
                        FIDOResetView()
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "trash"), color: Color(.systemRed), padding: 5)
                        Text("Reset FIDO application")
                    }
                }
                Section("PIV") {
                    NavigationLink {
                        SmartCardConfigurationView()
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "creditcard"), color: Color(.systemOrange))
                        Text("Smart card extension")
                    }
                }
            }
            .navigationTitle(String(localized: "Configuration", comment: "Configuration navigation title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close") {
                        showConfiguration.toggle()
                    }
                }
            }
        }
        .onChange(of: model.deviceInfo) { _ in
            withAnimation {
                showInsertYubiKey = model.deviceInfo == nil
            }
        }
        .onAppear {
            withAnimation {
                showInsertYubiKey = model.deviceInfo == nil
            }

            model.start()
        }
        .refreshable(enabled: YubiKitDeviceCapabilities.supportsISO7816NFCTags) {
            model.scanNFC()
        }
    }
}

struct ListIconView: View {
    
    var image: Image
    var color: Color
    var padding: CGFloat = 4.3
    
    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .font(Font.title.weight(.semibold))
            .padding(padding)
            .frame(width: 29, height: 29)
            .foregroundColor(.white)
            .background(color)
            .cornerRadius(6.5)
            .padding(.leading, -10)
    }
}

extension YKFManagementDeviceInfo {
    var deviceName: String {
        switch formFactor {
        case .usbaKeychain:
            let name: String
            if version.major == 5 { name = "5" } else
            if version.major < 4 { name = "NEO" }
            else { name = "" }
            return "YubiKey \(name) NFC"
        case .usbcKeychain:
            return "YubiKey 5C NFC"
        case .usbcLightning:
            return "YubiKey 5Ci"
        default:
            return "Unknown key"
        }
    }
    
    var deviceImage: Image? {
        switch formFactor {
        case .usbaKeychain:
            return Image("yk5nfc")
        case .usbcKeychain:
            return Image("yk5cnfc")
        case .usbcLightning:
            return Image("yk5ci")
        default:
            return nil
        }
    }
}
