//
//  PasswordStatusViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-10.
//  Copyright © 2021 Yubico. All rights reserved.
//

class PasswordStatusViewModel: NSObject, YKFManagerDelegate {
    
    enum PasswordStatus {
        case isProtected;
        case noPassword;
        case unknown;
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) { assert(false, "NFC did connect!") }
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) { assert(false, "NFC did disconnect!") }
    func didFailConnectingNFC(_ error: Error) {}
    
    private var accessoryConnection: YKFAccessoryConnection?

    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        connectionsCallback?(connection)
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        connectionsCallback?(nil)
    }
    
    private var connectionsCallback: ((_ connection: YKFAccessoryConnection?) -> Void)?
    private var passwordStatusCallback: ((_ status: PasswordStatus) -> Void)?

    private func connections(handler: @escaping (_ connection: YKFAccessoryConnection?) -> Void) {
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
                        let errorCode = YKFOATHErrorCode(rawValue: UInt((error as NSError).code))
                        if errorCode == .authenticationRequired {
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
        DelegateStack.shared.setDelegate(self)
    }
    
    deinit {
        print("Deinit PasswordStatusViewModel")
        DelegateStack.shared.removeDelegate(self)
    }
}
