//
//  YubiKeyInformationViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-06-18.
//  Copyright © 2021 Yubico. All rights reserved.
//

class YubiKeyInformationViewModel: NSObject {
    
    private var nfcConnection: YKFNFCConnection?
    private var accessoryConnection: YKFAccessoryConnection?

    var handler: ((_ result: Result<YKFManagementDeviceInfo, Error>?) -> Void)?
    
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
                YubiKitManager.shared.stopNFCConnection(withMessage: "YubiKey information read")
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
        return accessoryConnection ?? nfcConnection
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        didConnect(connection)
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
    }
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        didConnect(connection)
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        didDisconnect()
    }
}
