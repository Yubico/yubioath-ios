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

enum OATHSessionError: Error, LocalizedError, Equatable {
    
    case credentialAlreadyPresent(YKFOATHCredentialTemplate)
    case otpEnabledError
    case connectionCancelled
    case invalidDeviceInfo
    
    public var errorDescription: String? {
        switch self {
        case .credentialAlreadyPresent(let credential):
            return "\(String(localized: "There's already an account named", comment: "OATH substring in 'There's already an account named [issuer, name] on this YubiKey.")) \(credential.issuer.isEmpty == false ? "\(credential.issuer), \(credential.accountName)" : credential.accountName) \(String(localized: "on this YubiKey", comment: "OATH substring in 'There's already an account named [issuer, name] on this YubiKey."))."
        case .otpEnabledError:
            return String(localized: "Yubico OTP enabled", comment: "OATH otp enabled error message")
        case .connectionCancelled:
            return String(localized: "Connection cancelled by user", comment: "Internal error message not to be displayed to the user.")
        case .invalidDeviceInfo:
            return String(localized: "Invalid device info received from YubiKey", comment: "Internal error message not to be displayed to the user.")
        }
    }
}


class OATHSessionHandler: NSObject, YKFManagerDelegate {
    
    typealias ClosingCallback = ((_ error: Error?) -> Void)
    
    private var nfcConnection: YKFNFCConnection?
    private var smartCardConnection: YKFSmartCardConnection?
    private var accessoryConnection: YKFAccessoryConnection?
    
    private var currentSession: YKFOATHSession?
    
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
        struct AsyncIterator: AsyncIteratorProtocol {
            mutating func next() async throws -> Element? {
                guard !Task.isCancelled else {
                    return nil
                }
                while true {
                    return try await OATHSessionHandler.shared.newWiredSession()
                }
            }
        }
        
        func makeAsyncIterator() -> AsyncIterator {
            AsyncIterator()
        }
    }
    
    static let shared = OATHSessionHandler()
    
    func wiredSessions() -> OATHSessionHandler.WiredOATHSessions {
        return WiredOATHSessions()
    }
    
    func anySession() async throws -> OATHSession {
        if let currentSession {
            let type: OATHSession.ConnectionType = accessoryConnection == nil && smartCardConnection == nil ? .nfc : .wired
            return OATHSession(session: currentSession, type: type)
        } else if let smartCardConnection {
            let session = try await smartCardConnection.oathSession()
            currentSession = session
            return OATHSession(session: session, type: .wired)
        } else if let accessoryConnection {
            let session = try await accessoryConnection.oathSession()
            currentSession = session
            return OATHSession(session: session, type: .wired)
        } else {
            return try await nfcSession()
        }
    }
    
    var wiredContinuation: CheckedContinuation<OATHSession, Error>?
    private func newWiredSession() async throws -> OATHSession {
        YubiKitManager.shared.delegate = self
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            YubiKitManager.shared.startAccessoryConnection()
        }
        if #available(iOS 16.0, *) {
            YubiKitManager.shared.startSmartCardConnection()
        }

        return try await withTaskCancellationHandler {
            let deviceType = await UIDevice.current.userInterfaceIdiom
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OATHSession, Error>) in
                self.wiredContinuation = continuation
                self.wiredConnectionCallback = { connection in
                    if connection.isKind(of: YKFSmartCardConnection.self) && deviceType == .phone {
                        connection.managementSession { session, error in
                            guard let session else {
                                self.wiredContinuation?.resume(throwing: error!)
                                self.wiredContinuation = nil
                                self.wiredConnectionCallback = nil
                                return
                            }
                            session.getDeviceInfo { deviceInfo, error in
                                guard let deviceInfo else {
                                    self.wiredContinuation?.resume(throwing: error!)
                                    self.wiredContinuation = nil
                                    self.wiredConnectionCallback = nil
                                    return
                                }
                                guard let configuration = deviceInfo.configuration else {
                                    self.wiredContinuation?.resume(throwing: OATHSessionError.invalidDeviceInfo)
                                    self.wiredContinuation = nil
                                    self.wiredConnectionCallback = nil
                                    return
                                }
                                guard !configuration.isEnabled(.OTP, overTransport: .USB) || SettingsConfig.isOTPOverUSBIgnored(deviceId: deviceInfo.serialNumber) else {
                                    self.wiredContinuation?.resume(throwing: OATHSessionError.otpEnabledError)
                                    self.wiredContinuation = nil
                                    self.wiredConnectionCallback = nil
                                    return
                                }
                                connection.oathSession { session, error in
                                    if let session {
                                        self.currentSession = session
                                        self.wiredContinuation?.resume(returning: OATHSession(session: session, type: .wired))
                                    } else {
                                        self.wiredContinuation?.resume(throwing: error!)
                                    }
                                    self.wiredContinuation = nil
                                    self.wiredConnectionCallback = nil
                                    return
                                }
                            }
                        }
                    } else {
                        connection.oathSession { session, error in
                            if let session {
                                self.currentSession = session
                                self.wiredContinuation?.resume(returning: OATHSession(session: session, type: .wired))
                            } else {
                                self.wiredContinuation?.resume(throwing: error!)
                            }
                            self.wiredContinuation = nil
                            self.wiredConnectionCallback = nil
                        }
                    }
                }
                if let connection: YKFConnectionProtocol = self.accessoryConnection ?? self.smartCardConnection {
                    self.wiredConnectionCallback?(connection)
                }
            }
        } onCancel: {
            wiredContinuation?.resume(throwing: OATHSessionError.connectionCancelled)
            wiredContinuation = nil
            wiredConnectionCallback = nil
        }
    }
    
    var nfcContinuation: CheckedContinuation<OATHSession, Error>?
    func nfcSession() async throws -> OATHSession {
        return try await withTaskCancellationHandler {
            return try await withCheckedThrowingContinuation { continuation in
                self.nfcContinuation = continuation
                self.nfcConnectionCallback = { connection in
                    connection.oathSession { session, error in
                        if let session {
                            self.currentSession = session
                            self.nfcContinuation?.resume(returning: OATHSession(session: session, type: .nfc))
                        } else {
                            self.nfcContinuation?.resume(throwing: error!)
                        }
                        self.nfcContinuation = nil
                    }
                }
                YubiKitManager.shared.startNFCConnection()
            }
        } onCancel: {
            nfcContinuation?.resume(throwing: "Connection cancelled")
            nfcContinuation = nil
            nfcConnectionCallback = nil
            YubiKitManager.shared.stopNFCConnection()
        }
    }
    
}

class OATHSession {
    
    enum ConnectionType {
        case nfc
        case wired
    }
    
    enum CredentialType {
        case totp, hotp
    }
    
    class Credential: Equatable {
        static func == (lhs: OATHSession.Credential, rhs: OATHSession.Credential) -> Bool {
            return lhs.ykfCredential == rhs.ykfCredential
        }
        let type: CredentialType
        var label: String? {
            ykfCredential.label
        }
        var issuer: String? {
            get { ykfCredential.issuer }
            set { ykfCredential.issuer = newValue }
        }
        var accountName: String {
            get { ykfCredential.accountName }
            set { ykfCredential.accountName = newValue }
        }
        let period: UInt
        let requiresTouch: Bool
        var isSteam: Bool {
            ykfCredential.type == .TOTP && issuer?.lowercased() == "steam"
        }
        fileprivate let ykfCredential: YKFOATHCredential
        
        init(ykfCredential: YKFOATHCredential) {
            self.type = ykfCredential.type == .TOTP ? .totp : .hotp
            self.period = ykfCredential.period
            self.requiresTouch = ykfCredential.requiresTouch
            self.ykfCredential = ykfCredential
        }
    }
    
    struct OTP: Comparable {
        static func < (lhs: OATHSession.OTP, rhs: OATHSession.OTP) -> Bool {
            return lhs.code == rhs.code && lhs.validity == lhs.validity
        }
        
        let code: String
        let validity: DateInterval
    }
    
    private let session: YKFOATHSession
    public let type: ConnectionType
    public var version: YKFVersion {
        session.version
    }
    public var deviceId: String {
        session.deviceId
    }
    
    fileprivate init(session: YKFOATHSession, type: ConnectionType) {
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
    
    func addCredential(template: YKFOATHCredentialTemplate, requiresTouch: Bool) async throws {
        
        let credentials = try await session.listCredentials()
        let key = YKFOATHCredentialUtils.key(fromAccountName: template.accountName, issuer: template.issuer, period: template.period, type: template.type)
        let keys = credentials.map { YKFOATHCredentialUtils.key(fromAccountName: $0.accountName, issuer: $0.issuer, period: $0.period, type: $0.type) }
        guard !keys.contains(key) else {
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Duplicate accounts!", comment: "OATH add credential duplicate accounts error"))
            throw OATHSessionError.credentialAlreadyPresent(template)
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.put(template, requiresTouch: requiresTouch) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: Void())
            }
        }
    }
    
    func deleteCredential(_ credential: Credential) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.delete(credential.ykfCredential) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: Void())
            }
        }
    }
    
    func renameCredential(_ credential: Credential, issuer: String, accountName: String) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.renameCredential(credential.ykfCredential, newIssuer: issuer, newAccount: accountName) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: Void())
            }
        }
    }
    
    func list() async throws -> [Credential] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Credential], Error>) in
            session.listCredentials { credentials, error in
                if let credentials {
                    continuation.resume(returning: credentials.map { Credential(ykfCredential: $0) })
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    fatalError()
                }
            }
        }
    }
    
    func calculateAll(timestamp: Date = Date().addingTimeInterval(10) ) async throws -> [(Credential, OTP?)] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(Credential, OTP?)], Error>) in
            session.calculateAll(withTimestamp: timestamp) { credentials, error in
                if let credentials {
                    continuation.resume(returning: credentials.map { (Credential(ykfCredential: $0.credential), $0.code?.otpCode) })
                } else if let error {
                    continuation.resume(throwing: error)
                } else {
                    fatalError()
                }
            }
        }
    }
    
    func calculate(credential: Credential, timestamp: Date = Date().addingTimeInterval(10)) async throws -> OTP {
        return try await withCheckedThrowingContinuation { continuation in
            if credential.isSteam {
                session.calculateSteamTOTP(credential: credential.ykfCredential) { code, validity, error in
                    if let code, let validity {
                        continuation.resume(returning: OTP(code: code, validity: validity))
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        fatalError()
                    }
                }
            } else {
                session.calculate(credential.ykfCredential, timestamp: timestamp) { code, error in
                    if let code, let otp = code.otp {
                        continuation.resume(returning: OTP(code: otp, validity: code.validity))
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        fatalError()
                    }
                }
            }
        }
    }
    
    func unlock(password: String) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.unlock(withPassword: password) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func unlock(withPassword password: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let accessKey = session.deriveAccessKey(password)
            session.unlock(withAccessKey: accessKey) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(with: .success(accessKey))
                }
            }
        }
    }
    
    func unlock(withAccessKey accessKey: Data) async throws {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.unlock(withAccessKey: accessKey) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
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

extension YKFOATHCode {
    var otpCode: OATHSession.OTP? {
        guard let otp else { return nil }
        return OATHSession.OTP(code: otp, validity: validity)
    }
}
