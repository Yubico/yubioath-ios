//
//  Connection.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-04-27.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation


class Connection: NSObject, YKFManagerDelegate {
    
    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
        YubiKitManager.shared.startAccessoryConnection()
    }
    
    deinit {
        YubiKitManager.shared.delegate = nil
    }
    
    var connection: YKFConnectionProtocol? {
        return accessoryConnection ?? nfcConnection
    }
    
    var nfcConnection: YKFNFCConnection?

    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
        connectionCallback = nil
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        if let callback = disconnectionCallback {
            callback(connection, error)
        }
        connectionCallback = nil
        nfcConnection = nil
    }
    
    var accessoryConnection: YKFAccessoryConnection?

    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
        connectionCallback = nil
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        if let callback = disconnectionCallback {
            callback(connection, error)
        }
        connectionCallback = nil
        accessoryConnection = nil
    }
    
    var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    
    func startConnection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else if let connection = nfcConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            YubiKitManager.shared.startNFCConnection()
        }
    }
    
    var disconnectionCallback: ((_ connection: YKFConnectionProtocol, _ error: Error?) -> Void)?
    
    func didDisconnect(completion: @escaping (_ connection: YKFConnectionProtocol, _ error: Error?) -> Void) {
        disconnectionCallback = completion
    }
}
