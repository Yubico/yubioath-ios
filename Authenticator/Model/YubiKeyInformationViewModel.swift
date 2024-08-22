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

class YubiKeyInformationViewModel: NSObject {
    
    private var nfcConnection: YKFNFCConnection?
    private var accessoryConnection: YKFAccessoryConnection?
    private var smartCardConnection: YKFSmartCardConnection?
    
    var handler: ((_ result: Result<YKFManagementDeviceInfo, Error>?) -> Void)? {
        didSet {
            if let info = deviceInfo {
                handler?(.success(info))
            }
        }
    }
    
    var deviceInfo: YKFManagementDeviceInfo?
    
    override init() {
        super.init()
        DelegateStack.shared.setDelegate(self)
    }
    
    deinit {
        print("Deinit YubiKeyInformationViewModel")
        DelegateStack.shared.removeDelegate(self)
    }
    
    private func didConnect(_ connection: YKFConnectionProtocol) {
        connection.managementSession { session, error in
            guard let session = session else { self.handleError(error!, forConnection: connection); return }
            session.getDeviceInfo { info, error in
                guard let info = info else { self.handleError(error!, forConnection: connection); return }
                self.deviceInfo = info
                YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "YubiKey information read", comment: "YubiKey info NFC read"))
                self.handler?(.success(info))
            }
        }
    }
    
    private func didDisconnect() {
        self.handler?(nil)
    }
    
    func deviceInfo(handler: @escaping (_ result: Result<YKFManagementDeviceInfo, Error>?) -> Void) {
        self.handler = handler
    }
    
    private func handleError(_ error: Error, forConnection connection: YKFConnectionProtocol) {
        if (connection as? YKFNFCConnection) != nil {
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
            self.handler?(nil)
        } else {
            self.handler?(.failure(error))
        }
    }
}


//@available(iOS 14.0, *)
extension YubiKeyInformationViewModel: YKFManagerDelegate {
    
    var isKeyConnected: Bool {
        return connection != nil
    }
    
    var connection: YKFConnectionProtocol? {
        return accessoryConnection ?? smartCardConnection ?? nfcConnection
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        didConnect(connection)
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
    }
    
    func didFailConnectingNFC(_ error: Error) {}
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        didConnect(connection)
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        didDisconnect()
    }
    
    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        smartCardConnection = connection
        didConnect(connection)
    }
    
    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        smartCardConnection = nil
        didDisconnect()
    }
}
