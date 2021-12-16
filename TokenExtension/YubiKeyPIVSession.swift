//
//  YubiKeyConnection.swift
//  TokenExtension
//
//  Created by Jens Utbult on 2021-12-15.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import CommonCrypto
import CryptoKit

class YubiKeyPIVSession: NSObject {
    var accessoryConnection: YKFAccessoryConnection?
    var pivSession: YKFPIVSession?
    var pinVerified = false
    
    let semaphore = DispatchSemaphore(value: 0)
    
    public static var shared = YubiKeyPIVSession()
    
    private override init() {
        super.init()
        YubiKitManager.shared.delegate = self
    }
    
    var yubiKeyConnected: Bool {
        YubiKitManager.shared.startAccessoryConnection()
        _ = semaphore.wait(timeout: .now() + 2) // wait for 1 second for connection and session
        return pivSession != nil
    }
    
    func stop() {
        YubiKitManager.shared.stopAccessoryConnection()
    }

    func sign(objectId: String, type: TokenSession.KeyType, algorithm: SecKeyAlgorithm, message: Data, password: String) -> Data? {
        let semaphore = DispatchSemaphore(value: 0)
        var signedData: Data?
        self.sign(objectId: objectId, type: type, algorithm: algorithm, message: message, password: password) { data, error in
            signedData = data
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 8)
        self.stop()
        return signedData
    }
    
    private func sign(objectId: String, type: TokenSession.KeyType, algorithm: SecKeyAlgorithm, message: Data, password: String, completion: @escaping (Data?, Error?) -> Void) {
        guard let session = pivSession else { completion(nil, "No session"); return }
        session.slotForObjectId(objectId) { slot, error in
            guard let slot = slot else {
                completion(nil, error!)
                return
            }
            session.verifyPin(password) { result, error in
                if let error = error {
                    completion(nil, error)
                    return
                }
                session.signWithKey(in: slot, type: YKFPIVKeyType(rawValue: UInt(type.rawValue))!, algorithm: algorithm, message: message) { signature, error in
                    // Handle any errors
                    if let error = error { completion(nil, error); return }
                    guard let signature = signature else { fatalError() }
                    completion(signature, nil)
                }
            }
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

private extension YKFPIVSession {
    func slotForObjectId(_ objectId: String, completion: @escaping (YKFPIVSlot?, Error?) -> Void) {
        self.getCertificateIn(.authentication) { certificate, error in
            if let certificate = certificate, certificate.tokenObjectId() == objectId {
                print("Found matching certificate")
                completion(.authentication, nil)
                return
            }
            self.getCertificateIn(.signature) { certificate, error in
                if let certificate = certificate, certificate.tokenObjectId() == objectId {
                    print("Found matching certificate")
                    completion(.signature, nil)
                    return
                }
                self.getCertificateIn(.keyManagement) { certificate, error in
                    if let certificate = certificate, certificate.tokenObjectId() == objectId {
                        print("Found matching certificate")
                        completion(.keyManagement, nil)
                        return
                    }
                    self.getCertificateIn(.cardAuth) { certificate, error in
                        if let certificate = certificate, certificate.tokenObjectId() == objectId {
                            print("Found matching certificate")
                            completion(.cardAuth, nil)
                        } else if let apduError = error, (apduError as NSError).code != 0x6a82 {
                            completion(nil, "Communication error")
                        } else {
                            completion(nil, "No matching certificate on YubiKey")
                        }
                    }
                }
            }
        }
    }
}


extension SecCertificate: Equatable {
    
    var commonName: String? {
        var name: CFString?
        SecCertificateCopyCommonName(self, &name)
        return name as String?
    }
    
    func tokenObjectId() -> String {
        let data = SecCertificateCopyData(self) as Data
        return data.sha256Hash().map { String(format: "%02X", $0) }.joined()
    }
    
    func publicKey() -> SecKey? {
        return SecCertificateCopyKey(self)
    }
    
    public static func ==(lhs: SecCertificate, rhs: SecCertificate) -> Bool {
        return lhs.tokenObjectId() == rhs.tokenObjectId()
    }
}

extension Data {
    func sha256Hash() -> Data {
        let digest = SHA256.hash(data: self)
        let bytes = Array(digest.makeIterator())
        return Data(bytes)
    }
}

extension Data {
    var uint32: UInt32? {
        guard self.count == MemoryLayout<UInt32>.size else { return nil }
        return withUnsafeBytes { $0.load(as: UInt32.self) }
    }

    var uint64: UInt64? {
        guard self.count == MemoryLayout<UInt64>.size else { return nil }
        return withUnsafeBytes { $0.load(as: UInt64.self) }
    }
}
