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

class PasswordStatusViewModel: NSObject, YKFManagerDelegate {
    
    private var accessoryConnection: YKFAccessoryConnection?
    private var smartCardConnection: YKFSmartCardConnection?

    enum PasswordStatus {
        case isProtected;
        case noPassword;
        case unknown;
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) { assert(false, "NFC did connect!") }
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) { assert(false, "NFC did disconnect!") }
    func didFailConnectingNFC(_ error: Error) {}
    

    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        connectionsCallback?(connection)
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        connectionsCallback?(nil)
    }
    
    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        smartCardConnection = connection
        connectionsCallback?(connection)
    }
    
    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        connectionsCallback?(nil)
    }
    
    private var connectionsCallback: ((_ connection: YKFConnectionProtocol?) -> Void)?
    private var passwordStatusCallback: ((_ status: PasswordStatus) -> Void)?

    private func connections(handler: @escaping (_ connection: YKFConnectionProtocol?) -> Void) {
        connectionsCallback = handler
        if let connection = accessoryConnection {
            handler(connection)
        }
    }

    func subscribeToPasswordStatus(handler: @escaping (_ status: PasswordStatus) -> Void) {
        passwordStatusCallback = handler
        connections { [weak self] connection in
            guard let connection = connection else { self?.passwordStatusCallback?(.unknown); return }
            connection.managementSession { _, error in
                guard error == nil else { self?.passwordStatusCallback?(.unknown); return }
                connection.oathSession { session, error in
                    guard let session = session else { self?.passwordStatusCallback?(.unknown); return }
                    session.listCredentials { _, error in
                        guard let error = error else { self?.passwordStatusCallback?(.noPassword); return }
                        if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue {
                            self?.passwordStatusCallback?(.isProtected)
                        } else {
                            self?.passwordStatusCallback?(.unknown)
                        }
                    }
                }
            }
        }
    }
    
    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
    }
    
    deinit {
        print("Deinit PasswordStatusViewModel")
        YubiKitManager.shared.delegate = nil
    }
}
