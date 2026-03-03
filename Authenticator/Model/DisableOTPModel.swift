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

import Foundation
import OSLog

class DisableOTPModel: ObservableObject {

    @Published var keyIgnored: Bool = false
    @Published var isConfigurationLocked: Bool = false
    @Published var isDisablingOTP: Bool = false
    @Published var error: Error?

    init() {
        Logger.allocation.debug("DisableOTPModel: init")
        checkConfigurationLocked()
    }

    deinit {
        Logger.allocation.debug("DisableOTPModel: deinit")
    }

    private func checkConfigurationLocked() {
        Task { @MainActor in
            guard let connection = OATHSessionHandler.shared.smartCardConnection else { return }
            guard let session = try? await connection.managementSession() else { return }
            guard let deviceInfo = try? await session.deviceInfo() else { return }
            guard let configuration = deviceInfo.configuration else { return }
            self.isConfigurationLocked = configuration.isConfigurationLocked
        }
    }

    func disableOTP() {
        guard !isDisablingOTP else { return }
        isDisablingOTP = true
        Task { @MainActor in
            guard let connection = OATHSessionHandler.shared.smartCardConnection else { return }
            guard let session = try? await connection.managementSession() else { return }
            guard let deviceInfo = try? await session.deviceInfo() else { return }
            guard let configuration = deviceInfo.configuration else { return }
            configuration.setEnabled(false, application: .OTP, overTransport: .USB)
            do {
                try await session.write(configuration, reboot: true)
            } catch {
                self.error = error
                isDisablingOTP = false
            }
        }
    }

    func ignoreThisKey() {
        Task { @MainActor in
            guard let connection = OATHSessionHandler.shared.smartCardConnection else { return }
            guard let session = try? await connection.managementSession() else { return }
            guard let deviceInfo = try? await session.deviceInfo() else { return }
            SettingsConfig.registerUSBCDeviceToIgnore(deviceId: deviceInfo.serialNumber)
            self.keyIgnored = true
        }
    }
}
