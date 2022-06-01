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


class Connection: NSObject {
    
    override init() {
        super.init()
        DelegateStack.shared.setDelegate(self)
    }
    
    deinit {
        print("Deinit Connection")
        DelegateStack.shared.removeDelegate(self)
    }
    
    var connection: YKFConnectionProtocol? {
        return accessoryConnection ?? nfcConnection
    }
    
    private var nfcConnection: YKFNFCConnection?
    private var accessoryConnection: YKFAccessoryConnection?
    private var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    
    func startConnection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else if let connection = nfcConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
                YubiKitManager.shared.startNFCConnection()
            }
        }
    }
    
    private var accessoryConnectionCallback: ((_ connection: YKFAccessoryConnection?) -> Void)?
    
    func accessoryConnection(handler: @escaping (_ connection: YKFAccessoryConnection?) -> Void) {
        handler(accessoryConnection)
        accessoryConnectionCallback = handler
    }
    
    private var nfcConnectionCallback: ((_ connection: YKFNFCConnection?) -> Void)?
    
    func nfcConnection(handler: @escaping (_ connection: YKFNFCConnection?) -> Void) {
        handler(nfcConnection)
        nfcConnectionCallback = handler
    }
    
    private var disconnectionCallback: ((_ connection: YKFConnectionProtocol, _ error: Error?) -> Void)?
    
    func didDisconnect(handler: @escaping (_ connection: YKFConnectionProtocol, _ error: Error?) -> Void) {
        disconnectionCallback = handler
    }
}


extension Connection: YKFManagerDelegate {
    
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
    
    func didFailConnectingNFC(_ error: Error) {}
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        accessoryConnectionCallback?(connection)
        connectionCallback?(connection)
        connectionCallback = nil
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        disconnectionCallback?(connection, error)
        accessoryConnectionCallback?(nil)
        connectionCallback = nil
        accessoryConnection = nil
    }
    
}
