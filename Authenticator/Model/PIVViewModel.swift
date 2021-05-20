//
//  PIVViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-19.
//  Copyright © 2021 Yubico. All rights reserved.
//

class PIVViewModel: NSObject {
    
    private var nfcConnection: YKFNFCConnection?
    private var accessoryConnection: YKFAccessoryConnection?
    
    var certificatesCallback: ((_ result: Result<[SecCertificate], Error>) -> Void)?
    
    override init() {
        super.init()
        YubiKitManager.shared.delegate = self
    }
    
    private func didConnect() {
        updateCertificates()
    }
    
    private func didDisconnect() {
        self.certificatesCallback?(.success([SecCertificate]()))
    }
    
    func startNFC() {
        YubiKitManager.shared.startNFCConnection()
    }
    
    func copyCertificateToKeychain(certificate: SecCertificate) {
        print("copy to keychain: \(certificate)")
    }
    
    private func updateCertificates() {
        guard let connection = connection else { return }
        connection.pivSession { session, error in
            guard let session = session else { self.certificatesCallback?(.failure(error!)); return }
            guard let callback = self.certificatesCallback else { return }
            var certificates = [SecCertificate]()
            session.getCertificateIn(slot: .authentication, callback: callback) { certificate in
                if let certificate = certificate { certificates.append(certificate) }
                callback(.success(certificates))
                session.getCertificateIn(slot: .signature, callback: callback) { certificate in
                    if let certificate = certificate { certificates.append(certificate) }
                    callback(.success(certificates))
                    YubiKitManager.shared.stopNFCConnection(withMessage: "Finished reading certificates")
                    return
                }
            }
        }
    }
}

extension YKFPIVSession {
    func getCertificateIn(slot: YKFPIVSlot,
                          callback: @escaping (_ result: Result<[SecCertificate], Error>) -> Void,
                          completion: @escaping (_ certificate: SecCertificate?) -> Void) {
        getCertificateIn(slot) { certificate, error in
            guard let certificate = certificate else {
                if (error! as NSError).code == 0x6A82 {
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

extension PIVViewModel: YKFManagerDelegate {
    var connection: YKFConnectionProtocol? {
        return accessoryConnection ?? nfcConnection
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        didConnect()
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
    }
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        didConnect()
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        didDisconnect()
    }
}
