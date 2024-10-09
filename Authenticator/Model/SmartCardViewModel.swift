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
    }
    
    deinit {
        print("deinit SmartCardViewModel")
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
        result ? print("Sucessfully removed certificate from keychain") : print("Failed removing certificate from keychain!")
    }
    
    func update() {
        let tokens = tokenStorage.listTokenCertificates()
        tokensCallback?(.success(tokens))
        
        guard let connection = connection else { return }
        connection.pivSession { session, error in
            guard let session = session else { self.certificatesCallback?(.failure(error!)); return }
            guard let callback = self.certificatesCallback else { return }
            var certificates = [Certificate]()
            session.getCertificateIn(slot: .authentication, callback: callback) { certificate in
                if let certificate = certificate { certificates.append(Certificate(certificate: certificate, slot: .authentication)) }
                session.getCertificateIn(slot: .signature, callback: callback) { certificate in
                    if let certificate = certificate { certificates.append(Certificate(certificate: certificate, slot: .signature)) }
                    session.getCertificateIn(slot: .keyManagement, callback: callback) { certificate in
                        if let certificate = certificate { certificates.append(Certificate(certificate: certificate, slot: .keyManagement)) }
                        session.getCertificateIn(slot: .cardAuth, callback: callback) { certificate in
                            if let certificate = certificate { certificates.append(Certificate(certificate: certificate, slot: .cardAuth)) }
                            callback(.success(certificates))
                            YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Finished reading certificates", comment: "PIV extension NFC finished reading certs"))
                            return
                        }
                    }
                }
            }
        }
    }
}

@available(iOS 14.0, *)
extension YKFPIVSession {
    func getCertificateIn(slot: YKFPIVSlot,
                          callback: @escaping (_ result: Result<[SmartCardViewModel.Certificate]?, Error>) -> Void,
                          completion: @escaping (_ certificate: SecCertificate?) -> Void) {
        getCertificateIn(slot) { certificate, error in
            guard let certificate = certificate else {
                if (error! as NSError).code == 0x6A82 || (error! as NSError).code == YKFPIVErrorCode.dataParseError.rawValue {
                    completion(nil)
                } else {
                    callback(.failure(error!))
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                }
                return
            }
            completion(certificate)
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
