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

import Foundation
import YubiKit

enum ManagementViewModelError: Error {
    case unknownError;
    case missingDeviceConfiguration;
}
extension ManagementViewModelError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownError:
            return "Unknown error"
        case .missingDeviceConfiguration:
            return "Missing device configuration"
        }
    }
}

final class ManagementViewModel {

    struct OTPConfiguration: Sendable {
        let isEnabled: Bool
        let isSupported: Bool
        let isConfigurationLocked: Bool
        let transport: DeviceTransport
    }

    private var disconnectHandler: ((_ isNFC: Bool, _ error: Error?) -> Void)?

    /// Called when the YubiKey used to read the configuration is disconnected.
    func didDisconnect(completion: @escaping (_ isNFC: Bool, _ error: Error?) -> Void) {
        disconnectHandler = completion
    }

    func isOTPEnabled() async throws -> OTPConfiguration {
        do {
            let connection = try await ConnectionManager.shared.anyConnection()
            watchForDisconnect(of: connection)
            let transport: DeviceTransport = connection.isNFC ? .nfc : .usb
            let deviceInfo = try await connection.managementSession().getDeviceInfo()
            ConnectionManager.shared.closeNFC(message: String(localized: "Read YubiKey OTP configuration", comment: "Settings OTP configuration read"))
            return OTPConfiguration(isEnabled: deviceInfo.config.isApplicationEnabled(.otp, over: transport),
                                    isSupported: deviceInfo.isApplicationSupported(.otp, over: transport),
                                    isConfigurationLocked: deviceInfo.isConfigLocked,
                                    transport: transport)
        } catch {
            ConnectionManager.shared.closeNFC(errorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
            throw error
        }
    }

    private func watchForDisconnect(of connection: SmartCardConnection) {
        Task { [weak self] in
            let error = await ConnectionManager.shared.waitUntilClosed(connection)
            self?.disconnectHandler?(connection.isNFC, error)
            self?.disconnectHandler = nil
        }
    }

    /// Errors over NFC are shown in the NFC modal and not thrown.
    func setOTPEnabled(enabled: Bool) async throws {
        var isNFCConnection = false
        do {
            let connection = try await ConnectionManager.shared.anyConnection()
            isNFCConnection = connection.isNFC
            let transport: DeviceTransport = isNFCConnection ? .nfc : .usb
            let session = try await connection.managementSession()
            let config = try await session.getDeviceInfo().config
            let newConfig = enabled ? config.enable(application: .otp, over: transport) : config.disable(application: .otp, over: transport)
            try await session.updateDeviceConfig(newConfig, reboot: false)
            ConnectionManager.shared.closeNFC(message: String(localized: "New OTP configuration saved", comment: "Settings OTP configuration saved"))
        } catch where isNFCConnection {
            ConnectionManager.shared.closeNFC(errorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
        }
    }
}
