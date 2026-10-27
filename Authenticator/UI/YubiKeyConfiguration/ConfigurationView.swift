/*
 * Copyright (C) 2022 Yubico.
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
import YubiKit

struct ConfigurationView: View {
    @State var model = ConfigurationViewModel()
    @Binding var showConfiguration: Bool
    @State var showInsertYubiKey: Bool = false
    
    var insertYubiKeyMessage = {
        if DeviceCapabilities.supportsNFC {
            String(localized: "Insert YubiKey") + " " + "\(!UIAccessibility.isVoiceOverRunning ? String(localized: "or pull down to activate NFC") : String(localized: "or scan a NFC YubiKey"))"
        } else {
            String(localized: "Insert YubiKey")
        }
    }()
    
    var body: some View {
        NavigationStack {
            List {
                if model.deviceInfo == nil {
                    VStack(alignment: .center) {
                        Image("yubikey")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundStyle(Color(.symbol))
                            .padding(15)
                            .accessibilityHidden(true)
                        Text(insertYubiKeyMessage)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.horizontal, 20)
                    .listRowBackground(Color.black.opacity(0))
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
                Section("General") {
                    NavigationLink {
                        OTPConfigurationView()
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationTitle("Toggle One-Time Password")
                            .onDisappear {
                                model.start()
                            }
                    } label: {
                        ListIconView(image: Image(systemName: "ellipsis.rectangle"), color: Color(.systemBlue))
                        Text("Toggle One-Time Password")
                    }
                    if DeviceCapabilities.supportsNFCScanning {
                        NavigationLink {
                            NFCSettingsView()
                                .navigationBarTitleDisplayMode(.inline)
                                .navigationTitle("NFC settings")
                                .onDisappear {
                                    model.start()
                                }
                        } label: {
                            ListIconView(image: Image(systemName: "dot.radiowaves.left.and.right"), color: Color(.systemBlue))
                            Text("NFC settings")
                        }
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
                        ListIconView(image: Image(systemName: "xmark.circle"), color: Color(.systemPink), padding: 5)
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
                if DeviceCapabilities.supportsLightning || DeviceCapabilities.supportsNFC {
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
                            FIDOResetView {
                                Task {
                                    model.start()
                                }
                            }
                        } label: {
                            ListIconView(image: Image(systemName: "trash"), color: Color(.systemRed), padding: 5)
                            Text("Reset FIDO application")
                        }
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
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton { showConfiguration.toggle() }
                }
                if UIAccessibility.isVoiceOverRunning {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            model.scanNFC()
                        } label: {
                            Label(String(localized: "Scan NFC YubiKey"), systemImage: "wave.3.right")
                        }
                    }
                }
            }
        }
        .onChange(of: model.deviceInfo == nil) { _, _ in
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
        .refreshable(enabled: DeviceCapabilities.supportsNFC) {
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
            .foregroundStyle(.white)
            .background(color)
            .clipShape(.rect(cornerRadius: 6.5))
    }
}

extension DeviceInfo {
    var deviceName: String {

        let deviceName: String
        switch formFactor {
        case .usbAKeychain:
            let name: String
            if version.major == 5 { name = "5" } else
            if version.major < 4 { name = "NEO" }
            else { name = "" }
            deviceName = "YubiKey \(name) NFC"
            break
        case .usbCKeychain:
            deviceName = "YubiKey 5C NFC"
        case .usbCLightning:
            deviceName = "YubiKey 5Ci"
        case .usbCBio, .usbABio:
            deviceName = "YubiKey Bio"
        case .usbCNano:
            deviceName = "YubiKey Nano"
        default:
            return "Unknown key"
        }

        if (fipsCapabilityFlags != 0) || isFIPS {
            return deviceName + " FIPS"
        } else {
            return deviceName
        }
    }
    
    var deviceImage: Image? {
        switch formFactor {
        case .usbAKeychain:
            return Image("yk5nfc")
        case .usbCKeychain:
            return Image("yk5cnfc")
        case .usbCLightning:
            return Image("yk5ci")
        case .usbCBio:
            return Image("ykbioc")
        case .usbABio:
            return Image("ykbioa")
        default:
            return nil
        }
    }
}
