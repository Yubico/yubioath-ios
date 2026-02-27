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

import OSLog

@available(iOS 14.0, *)

class SmartCardViewModel: NSObject {
    
    struct Certificate {
        let certificate: SecCertificate
        let slot: YKFPIVSlot
    }
    
    private var nfcConnection: YKFNFCConnection?
    private var accessoryConnection: YKFAccessoryConnection?
    private var smartCardConnection: YKFSmartCardConnection?
    
    private let tokenStorage = TokenCertificateStorage()
    
    var certificatesCallback: ((_ result: Result<[Certificate]?, Error>) -> Void)?
    var tokensCallback: ((_ result: Result<[SecCertificate], Error>) -> Void)?
    
    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
        Logger.allocation.debug("SmartCardViewModel: init")
    }
    
    deinit {
        Logger.allocation.debug("SmartCardViewModel: deinit")
    }
    
    private func didConnect() {
        update()
    }
    
    private func didDisconnect() {
        self.certificatesCallback?(.success(nil))
    }
    
    func startNFC() {
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            YubiKitManager.shared.startNFCConnection()
        }
    }
    
    func storeTokenCertificate(certificate: SecCertificate) -> Error? {
        return tokenStorage.storeTokenCertificate(certificate: certificate)
    }
    
    func removeTokenCertificate(certificate: SecCertificate) {
        let result = tokenStorage.removeTokenCertificate(certificate: certificate)
        result ? Logger.ctk.debug("Sucessfully removed certificate from keychain") : Logger.ctk.debug("Failed removing certificate from keychain!")
    }
    
    func update() {
        let tokens = tokenStorage.listTokenCertificates()
        tokensCallback?(.success(tokens))

        guard let connection = connection else { return }

        Task {
            do {
                let session = try await connection.pivSession()
                var certificates = [Certificate]()

                for slot in YKFPIVSlot.allSlots {
                    if let cert = try await session.getCertificate(in: slot) {
                        certificates.append(Certificate(certificate: cert, slot: slot))
                    }
                }

                certificatesCallback?(.success(certificates))
                YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Finished reading certificates", comment: "PIV extension NFC finished reading certs"))
            } catch {
                certificatesCallback?(.failure(error))
                YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
            }
        }
    }
}

@available(iOS 14.0, *)
extension YKFPIVSlot {
    static let allSlots: [YKFPIVSlot] = [
        .authentication, .signature, .keyManagement, .cardAuth,
        .retired1, .retired2, .retired3, .retired4, .retired5,
        .retired6, .retired7, .retired8, .retired9, .retired10,
        .retired11, .retired12, .retired13, .retired14, .retired15,
        .retired16, .retired17, .retired18, .retired19, .retired20
    ]
}

@available(iOS 14.0, *)
extension YKFConnectionProtocol {
    func pivSession() async throws -> YKFPIVSession {
        try await withCheckedThrowingContinuation { continuation in
            pivSession { session, _, error in
                if let session {
                    continuation.resume(returning: session)
                } else {
                    continuation.resume(throwing: error!)
                }
            }
        }
    }
}

@available(iOS 14.0, *)
extension YKFPIVSession {
    func getCertificate(in slot: YKFPIVSlot) async throws -> SecCertificate? {
        try await withCheckedThrowingContinuation { continuation in
            getCertificateIn(slot) { certificate, error in
                if let certificate {
                    continuation.resume(returning: certificate)
                } else if let error = error as NSError?,
                          error.code == 0x6A82 || error.code == YKFPIVErrorCode.dataParseError.rawValue {
                    // No certificate in slot - not an error
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(throwing: error!)
                }
            }
        }
    }
}

@available(iOS 14.0, *)
extension SmartCardViewModel: YKFManagerDelegate {
    
    var isKeyConnected: Bool {
        return connection != nil
    }
    
    var connection: YKFConnectionProtocol? {
        return accessoryConnection ?? smartCardConnection ?? nfcConnection
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        didConnect()
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
    }
    
    func didFailConnectingNFC(_ error: Error) {}
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        didConnect()
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        didDisconnect()
    }
    
    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        smartCardConnection = connection
        didConnect()
    }
    
    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        smartCardConnection = nil
        didDisconnect()
    }
}
