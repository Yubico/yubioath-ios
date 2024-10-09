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
        print("init Connection")
//        assert(YubiKitManager.shared.delegate == nil)
        YubiKitManager.shared.delegate = self
    }
    
    deinit {
        print("Deinit Connection")
//        YubiKitManager.shared.delegate = nil
    }
    
    var connection: YKFConnectionProtocol? {
        return accessoryConnection ?? smartCardConnection ?? nfcConnection
    }
    
    private var nfcConnection: YKFNFCConnection?
    private var smartCardConnection: YKFSmartCardConnection?
    private var accessoryConnection: YKFAccessoryConnection?
    
    private var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    private var disconnectionCallback: ((_ connection: YKFConnectionProtocol?, _ error: Error?) -> Void)? {
        didSet {
            print("didSet disconnectionCallback: \(disconnectionCallback)")
        }
    }
    
    private var accessoryConnectionCallback: ((_ connection: YKFAccessoryConnection?) -> Void)?
    private var nfcConnectionCallback: ((_ connection: YKFNFCConnection?) -> Void)?
    private var smartCardConnectionCallback: ((_ connection: YKFSmartCardConnection?) -> Void)?

    func startConnection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        YubiKitManager.shared.delegate = self

        if let connection = accessoryConnection {
            completion(connection)
        } else if let connection = smartCardConnection {
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
    
    func startWiredConnection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        connectionCallback = completion
        YubiKitManager.shared.delegate = self
    }
    
    func accessoryConnection(handler: @escaping (_ connection: YKFAccessoryConnection?) -> Void) {
        if let connection = accessoryConnection {
            handler(connection)
        } else {
            accessoryConnectionCallback = handler
        }
    }
    
    func smartCardConnection(handler: @escaping (_ connection: YKFSmartCardConnection?) -> Void) {
        if let connection = smartCardConnection {
            handler(connection)
        } else {
            smartCardConnectionCallback = handler
        }
    }
    
    func nfcConnection(handler: @escaping (_ connection: YKFNFCConnection?) -> Void) {
        if let connection = nfcConnection {
            handler(connection)
        } else {
            nfcConnectionCallback = handler
        }
    }
    
    func stop() {
        smartCardConnection?.stop()
        accessoryConnection?.stop()
        nfcConnection?.stop()
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            YubiKitManager.shared.startAccessoryConnection()
        }
        if YubiKitDeviceCapabilities.supportsSmartCardOverUSBC {
            YubiKitManager.shared.startSmartCardConnection()
        }
    }
    
    func didDisconnect(handler: @escaping (_ connection: YKFConnectionProtocol?, _ error: Error?) -> Void) {
        disconnectionCallback = handler
        print(disconnectionCallback)
    }
}


extension Connection: YKFManagerDelegate {
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        nfcConnectionCallback?(connection)
        nfcConnectionCallback = nil
        connectionCallback?(connection)
        connectionCallback = nil
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
        nfcConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(connection, error)
        disconnectionCallback = nil
    }
    
    func didFailConnectingNFC(_ error: Error) {
        nfcConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(nil, error)
        disconnectionCallback = nil
    }
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        print("didConnectAccessory")
        accessoryConnection = connection
        accessoryConnectionCallback?(connection)
        accessoryConnectionCallback = nil
        connectionCallback?(connection)
        connectionCallback = nil
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        accessoryConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(connection, error)
        disconnectionCallback = nil
    }
    
    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        print("didConnectSmartCard")
        smartCardConnection = connection
        smartCardConnectionCallback?(connection)
        smartCardConnectionCallback = nil
        connectionCallback?(connection)
        connectionCallback = nil
    }
    
    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        print("didDisconnectSmartCard")
        smartCardConnection = nil
        smartCardConnectionCallback = nil
        connectionCallback = nil
        disconnectionCallback?(connection, error)
        disconnectionCallback = nil
    }
    
}
