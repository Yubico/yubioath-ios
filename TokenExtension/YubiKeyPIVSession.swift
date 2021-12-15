//
//  YubiKeyConnection.swift
//  TokenExtension
//
//  Created by Jens Utbult on 2021-12-15.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

class YubiKeyPIVSession: NSObject {
    var accessoryConnection: YKFAccessoryConnection?
    var pivSession: YKFPIVSession?
    var pinVerified = false
    
    let semaphore = DispatchSemaphore(value: 0)
    
    public static var shared = YubiKeyPIVSession()
    
    private override init() {
        super.init()
        YubiKitManager.shared.delegate = self
        YubiKitManager.shared.startAccessoryConnection()
        Thread.sleep(forTimeInterval: 0.3)
    }
    
    var yubiKeyConnected: Bool {
        if pivSession != nil { return true }
        _ = semaphore.wait(timeout: .now() + 1) // wait for 1 second for connection and session
        return pivSession != nil
    }
    
    func verify(pin: String) -> Error? {
        pinVerified = false
        let semaphore = DispatchSemaphore(value: 0)
        var resultError: Error?
        var success = false
        if let session = pivSession {
            session.verifyPin(pin) { _, error in
                semaphore.signal()
                success = error != nil
                resultError = error
            }
        } else {
            resultError = "No session"
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1)
        
        if success {
            pinVerified = true
            return nil
        } else {
            return resultError ?? "timeout"
        }
    }
}

extension YKFAccessoryConnection {
    func verify(pin: String) -> Error? {
        let semaphore = DispatchSemaphore(value: 0)
        var resultError: Error?
        var success = false
        self.pivSession { session, error in
            if let session = session {
                session.verifyPin(pin) { _, error in
                    semaphore.signal()
                    success = error != nil
                    resultError = error
                }
            } else {
                resultError = error
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .now() + 1)
        
        if success {
            return nil
        } else {
            return resultError ?? "timeout"
        }
    }
}

extension YubiKeyPIVSession: YKFManagerDelegate {
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        connection.pivSession { session, error in
            self.pivSession = session
            self.semaphore.signal()
        }
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        pivSession = nil
    }
    
}
