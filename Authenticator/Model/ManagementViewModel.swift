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

import Foundation

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

class ManagementViewModel {

    struct OTPConfiguration {
        let isEnabled: Bool
        let isSupported: Bool
        let isConfigurationLocked: Bool
        let transport: YKFManagementTransportType
    }
    
    let connection = Connection()

    func didDisconnect(completion: @escaping (_ connection: YKFConnectionProtocol?, _ error: Error?) -> Void) {
        connection.didDisconnect(handler: completion)
    }
    
    func isOTPEnabled(completion: @escaping (_ result: Result<OTPConfiguration, Error>) -> Void) {
        connection.startConnection { connection in
            connection.managementSession { session, error in
                guard let session = session else {
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error?.localizedDescription ?? "Unknown error")
                    completion(.failure(error!))
                    return
                }
                    session.getDeviceInfo { deviceInfo, error in
                        YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Read YubiKey OTP configuration", comment: "Settings OTP configuration read"))
                    guard let deviceInfo = deviceInfo else { completion(.failure(error!)); return }
                    guard let configuration = deviceInfo.configuration else {
                        completion(.failure(ManagementViewModelError.unknownError))
                        return }
                    let transport: YKFManagementTransportType = connection as? YKFNFCConnection != nil ? .NFC : .USB
                    let otpConfiguration = OTPConfiguration(isEnabled: configuration.isEnabled(.OTP, overTransport: transport),
                                                            isSupported: configuration.isSupported(.OTP, overTransport: transport),
                                                            isConfigurationLocked: configuration.isConfigurationLocked,
                                                            transport: transport)
                    completion(.success(otpConfiguration))
                }
            }
        }
    }
    
    private func handleError(error: Error, forConnection connection: YKFConnectionProtocol) -> Error? {
        if (connection as? YKFNFCConnection) != nil {
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
            return nil // Dont pass on the error since we display it in the NFC modal
        } else {
            return error
        }
    }
    
    func setOTPEnabled(enabled: Bool, completion: @escaping (_ error: Error?) -> Void) {
        connection.startConnection { connection in
            connection.managementSession { session, error in
                guard let session = session else {
                    let errorToPassOn = self.handleError(error: error!, forConnection: connection)
                    completion(errorToPassOn)
                    return
                }
                session.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo = deviceInfo else {
                        let errorToPassOn = self.handleError(error: error!, forConnection: connection)
                        completion(errorToPassOn)
                        return
                    }
                    guard let configuration = deviceInfo.configuration else { completion(ManagementViewModelError.missingDeviceConfiguration); return }
                    let transport: YKFManagementTransportType = connection as? YKFNFCConnection != nil ? .NFC : .USB
                    configuration.setEnabled(enabled, application: .OTP, overTransport: transport)
                    session.write(configuration, reboot: false) { error in
                        if let error = error {
                            let errorToPassOn = self.handleError(error: error, forConnection: connection)
                            completion(errorToPassOn)
                            return
                        } else {
                            YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "New OTP configuration saved", comment: "Settings OTP configuration saved"))
                        }
                        completion(nil)
                    }
                }
            }
        }
    }
}
