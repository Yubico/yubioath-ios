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

import Foundation
import OSLog
import YubiKit

@Observable class DisableOTPModel {

    var keyIgnored: Bool = false
    var isConfigurationLocked: Bool = false
    var isDisablingOTP: Bool = false
    var error: Error?

    init() {
        Logger.allocation.debug("DisableOTPModel: init")
    }

    deinit {
        Logger.allocation.debug("DisableOTPModel: deinit")
    }

    func checkConfigurationLocked() {
        Task {
            guard let connection = ConnectionManager.shared.wiredConnection else { return }
            guard let session = try? await connection.managementSession() else { return }
            guard let deviceInfo = try? await session.getDeviceInfo() else { return }
            self.isConfigurationLocked = deviceInfo.isConfigLocked
        }
    }

    func disableOTP() {
        guard !isDisablingOTP else { return }
        isDisablingOTP = true
        Task {
            guard let connection = ConnectionManager.shared.wiredConnection else { return }
            guard let session = try? await connection.managementSession() else { return }
            guard let deviceInfo = try? await session.getDeviceInfo() else { return }
            do {
                try await session.updateDeviceConfig(deviceInfo.config.disable(application: .otp, over: .usb), reboot: true)
            } catch {
                self.error = error
                isDisablingOTP = false
            }
        }
    }

    func ignoreThisKey() {
        Task {
            guard let connection = ConnectionManager.shared.wiredConnection else { return }
            guard let session = try? await connection.managementSession() else { return }
            guard let deviceInfo = try? await session.getDeviceInfo() else { return }
            SettingsConfig.registerUSBCDeviceToIgnore(deviceId: deviceInfo.serialNumber)
            self.keyIgnored = true
        }
    }
}
