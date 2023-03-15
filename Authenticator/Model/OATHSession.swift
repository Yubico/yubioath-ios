/*
 * Copyright (C) Yubico.
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

class OATHSessionHandler: NSObject, YKFManagerDelegate {
    
    typealias ClosingCallback = ((_ error: Error?) -> Void)
    
    private var nfcConnection: YKFNFCConnection?
    private var smartCardConnection: YKFSmartCardConnection?
    private var accessoryConnection: YKFAccessoryConnection?
    
    private var currentSession: YKFOATHSession? = nil
    
    private var nfcConnectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    private var wiredConnectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    fileprivate var closingCallback: ClosingCallback?

    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        nfcConnectionCallback?(connection)
        nfcConnectionCallback = nil
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
        closingCallback?(error)
        closingCallback = nil
        currentSession = nil
    }
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        wiredConnectionCallback?(connection)
        wiredConnectionCallback = nil
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        closingCallback?(error)
        closingCallback = nil
        currentSession = nil
    }
    
    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        smartCardConnection = connection
        wiredConnectionCallback?(connection)
        wiredConnectionCallback = nil
    }
    
    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        smartCardConnection = nil
        closingCallback?(error)
        closingCallback = nil
        currentSession = nil
    }
    
    struct WiredOATHSessions: AsyncSequence {
        typealias Element = OATHSession
        var current: OATHSession? = nil
        struct AsyncIterator: AsyncIteratorProtocol {
            mutating func next() async -> Element? {
                while true {
                    return try? await OATHSessionHandler.shared.wiredSession(useCached: false)
                }
            }
        }
        
        func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator()
        }
    }
    
    
    static let shared = OATHSessionHandler()
    private override init() {
        print("👾 startAccessoryConnection")
        super.init()
        DelegateStack.shared.setDelegate(self)
        YubiKitManager.shared.startAccessoryConnection()
    }
    
    func wiredSessions() -> OATHSessionHandler.WiredOATHSessions {
        return WiredOATHSessions()
    }
    
    func anySession() async throws -> OATHSession {
        if let currentSession {
            let type: OATHSession.ConnectionType = accessoryConnection == nil && smartCardConnection == nil ? .nfc : .wired
            return OATHSession(session: currentSession, type: type)
        } else if let smartCardConnection {
            let session = try await smartCardConnection.oathSession()
            return OATHSession(session: session, type: .wired)
        } else if let accessoryConnection {
            let session = try await accessoryConnection.oathSession()
            return OATHSession(session: session, type: .wired)
        } else {
            return try await nfcSession()
        }
    }
    
    func wiredSession(useCached: Bool = true) async throws -> OATHSession {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OATHSession, Error>) in
            if useCached {
                if let currentSession {
                    continuation.resume(returning: OATHSession(session: currentSession, type: .wired))
                } else if let connection: YKFConnectionProtocol = smartCardConnection ?? accessoryConnection {
                    connection.oathSession { session, error in
                        if let session {
                            self.currentSession = session
                            continuation.resume(returning: OATHSession(session: session, type: .wired))
                        } else {
                            continuation.resume(throwing: error!)
                        }
                    }
                }
            }
            self.wiredConnectionCallback = { connection in
                print("👾 wait for a wired connection")
                connection.oathSession { session, error in
                    if let session {
                        self.currentSession = session
                        continuation.resume(returning: OATHSession(session: session, type: .wired))
                    } else {
                        continuation.resume(throwing: error!)
                    }
                }
            }
        }
    }
    
    func nfcSession() async throws -> OATHSession {
        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                self.nfcConnectionCallback = { connection in
                    connection.oathSession { session, error in
                        if let session {
                            self.currentSession = session
                            continuation.resume(returning: OATHSession(session: session, type: .nfc))
                        } else {
                            continuation.resume(throwing: error!)
                        }
                    }
                }
                YubiKitManager.shared.startNFCConnection()
            }
        } onCancel: {
            print("👾 cancel nfc connection")
            YubiKitManager.shared.stopNFCConnection()
        }
    }
    
}

class OATHSession {
    
    enum ConnectionType {
        case nfc
        case wired
    }
    
    private let session: YKFOATHSession
    public let type: ConnectionType

    init(session: YKFOATHSession, type: ConnectionType) {
        self.session = session
        self.type = type
    }
    
    func sessionDidEnd() async -> Error? {
        return await withCheckedContinuation { continuation in
            OATHSessionHandler.shared.closingCallback = { error in
                continuation.resume(returning: error)
            }
        }
    }
    
    func addAccount(template: YKFOATHCredentialTemplate, requiresTouch: Bool) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.put(template, requiresTouch: requiresTouch) { error in
                if let error {
                    continuation.resume(throwing: error)
                }
                continuation.resume(returning: Void())
            }
        }
    }
    
    func deleteAccount(account: YKFOATHCredential) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.delete(account) { error in
                if let error {
                    continuation.resume(throwing: error)
                }
                continuation.resume(returning: Void())
            }
        }
    }
    
    func calculateAll(timestamp: Date = Date().addingTimeInterval(10) ) async throws -> [YKFOATHCredentialWithCode] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[YKFOATHCredentialWithCode], Error>) in
            session.calculateAll(withTimestamp: timestamp) { credentials, error in
                if let credentials {
                    continuation.resume(returning: credentials)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    fatalError()
                }
            }
        }
    }
    
    func calculate(credential: YKFOATHCredential, timestamp: Date = Date().addingTimeInterval(10)) async throws -> YKFOATHCode {
        return try await withCheckedThrowingContinuation { continuation in
            session.calculate(credential, timestamp: timestamp) { code, error in
                if let code {
                    continuation.resume(returning: code)
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    fatalError()
                }
            }
        }
    }
    
    func unlock(password: String) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.unlock(withPassword: password) { error in
                if let error {
                    print("👾 failed unlocking: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    print("👾 unlocked!")
                    continuation.resume()
                }
            }
        }
    }
    
    func endNFC(message: String? = nil) {
        if let message {
            YubiKitManager.shared.stopNFCConnection(withMessage: message)
        } else {
            YubiKitManager.shared.stopNFCConnection()
        }
    }
}
