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

class DisableOTPModel: ObservableObject {
    private let sessionHandler = ManagementSessionHandler()
    
    @Published var otpDisabled: Bool = false
    @Published var keyRemoved: Bool = false
    @Published var keyIgnored: Bool = false
    
    init() {
        sessionHandler.closingCallback = { [weak self] error in
            DispatchQueue.main.async {
                self?.keyRemoved = true
            }
        }
    }
    
    func disableOTP() {
        Task { @MainActor in
            guard let session = try? await self.sessionHandler.session() else { return }
            guard let deviceInfo = try? await session.deviceInfo() else { return }
            guard let configuration = deviceInfo.configuration else { return }
            configuration.setEnabled(false, application: .OTP, overTransport: .USB)
            try await session.write(configuration, reboot: false)
            self.otpDisabled = true
        }
    }
    
    func ignoreThisKey() {
        Task { @MainActor in
            guard let session = try? await self.sessionHandler.session() else { return }
            guard let deviceInfo = try? await session.deviceInfo() else { return }
            SettingsConfig.registerUSBCDeviceToIgnore(deviceId: deviceInfo.serialNumber)
            self.keyIgnored = true
        }
    }
}

fileprivate class ManagementSessionHandler: NSObject, YKFManagerDelegate {
    
    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
    }
    
    deinit {
        YubiKitManager.shared.delegate = nil
    }
    
    private var smartCardConnection: YKFSmartCardConnection?
    private var currentSession: YKFManagementSession?
    
    private var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    fileprivate var closingCallback: ((_ error: Error?) -> Void)?
    
    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        print(connection.smartCardInterface.hashValue)
        smartCardConnection = connection
        connectionCallback?(connection)
        connectionCallback = nil
    }
    
    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        smartCardConnection = nil
        closingCallback?(error)
        closingCallback = nil
        currentSession = nil
    }
    
    var completion: ((YKFNFCConnection) -> Void)?
    
    func session() async throws -> YKFManagementSession {
        return try await withCheckedThrowingContinuation { continuation in
            guard !Task.isCancelled else {
                continuation.resume(throwing: CancellationError())
                return
            }
            if let smartCardConnection {
                smartCardConnection.managementSession { session, error in
                    if let session {
                        continuation.resume(returning: session)
                    } else {
                        continuation.resume(throwing: error!)
                    }
                }
                return
            }
            
            self.completion = { connection in
                connection.managementSession { session, error in
                    if let session {
                        continuation.resume(returning: session)
                    } else {
                        continuation.resume(throwing: error!)
                    }
                    self.completion = nil
                }
            }
        }
    }
}

extension ManagementSessionHandler {
    // Not used but implemented to conform to YKFManagerDelegate protocol.
    func didConnectNFC(_ connection: YKFNFCConnection) { }
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) { }
    func didConnectAccessory(_ connection: YKFAccessoryConnection) { }
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) { }
}
