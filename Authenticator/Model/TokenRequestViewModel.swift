//
//  TokenRequestViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-25.
//  Copyright © 2021 Yubico. All rights reserved.
//

@available(iOS 14.0, *)
extension Error {
    var tokenError: TokenRequestViewModel.TokenError {
        let code = YKFPIVFErrorCode(rawValue: UInt((self as NSError).code))
        switch code {
        case .pinLocked:
            return .passwordLocked(TokenRequestViewModel.ErrorMessage(title: "Your PIN has ben blocked", text: "Use your PUK code to reset PIN."))
        case .invalidPin:
            return .wrongPassword(TokenRequestViewModel.ErrorMessage(title: "Wrong PIN code", text: nil))
        default:
            return .notHandled(TokenRequestViewModel.ErrorMessage(title: self.localizedDescription, text: nil))
        }
    }
}

@available(iOS 14.0, *)
class TokenRequestViewModel: NSObject {
    
    enum TokenError: Error {
        case wrongPassword(ErrorMessage)
        case passwordLocked(ErrorMessage)
        case notHandled(ErrorMessage)
        case missingCertificate(ErrorMessage)
        case communicationError(ErrorMessage)
        case alreadyHandled
        
        var message: ErrorMessage {
            switch self {
            case .wrongPassword(let message):
                return message
            case .passwordLocked(let message):
                return message
            case .notHandled(let message):
                return message
            case .missingCertificate(let message):
                return message
            case .communicationError(let message):
                return message
            case .alreadyHandled:
                return ErrorMessage(title: "Already handled", text: nil)
            }
        }
    }
    
    struct ErrorMessage {
        var title: String
        var text: String?
    }
    
    private var connection = Connection()
    
    override init() {
        super.init()
    }
    
    deinit {
        print("Deinit TokenRequestViewModel")
    }
    
    var isAccessoryKeyConnectedHandler: ((Bool) -> Void)?
    
    func isAccessoryKeyConnected(handler: @escaping (Bool) -> Void) {
        isAccessoryKeyConnectedHandler = handler
        connection.accessoryConnection { [weak self] connection in
            DispatchQueue.main.async {
                self?.isAccessoryKeyConnectedHandler?(connection != nil)
            }
        }
    }

    func handleTokenRequest(_ userInfo: [AnyHashable: Any], password: String, completion: @escaping (TokenError?) -> Void) {
        connection.startConnection { connection in
            print("🦠 Got connection \(connection)")
            connection.pivSession { session, error in
                print("🦠 Got session \(session)")
                guard let session = session else { print("No session: \(error!)"); return }
                guard let type = userInfo.keyType(),
                      let objectId = userInfo.objectId(),
                      let algorithm = userInfo.algorithm(),
                      let message = userInfo.data() else { print("No data to sign"); return }
                print("Search for slot for objectId: \(objectId)")
                session.slotForObjectId(objectId) { slot, error in
                    guard let slot = slot else {
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.message.title)
                        completion(error!)
                        return
                    }
                    session.verifyPin(password) { result, error in
                        if let error = error {
                            let tokenError = error.tokenError
                            switch tokenError {
                            case .wrongPassword(let message):
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: message.title)
                                if connection as? YKFNFCConnection != nil { completion(.alreadyHandled) }
                                else { completion(tokenError) }
                                return
                            default:
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: tokenError.message.title)
                                completion(tokenError)
                                return
                            }
                        }
                        session.signWithKey(in: slot, type: type, algorithm: algorithm, message: message) { signature, error in
                            // Handle any errors
                            if let error = error, (error as NSError).code == 0x6a80 {
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Invalid signature")
                                completion(.communicationError(ErrorMessage(title: "Invalid signature", text: "The private key on the YubiKey does not match the certificate or there is no private key stored on the YubiKey.")))
                                return
                            }
                            if let error = error {
                                completion(.communicationError(ErrorMessage(title: "Signing failed", text: error.localizedDescription)))
                                return
                            }
                            guard let signature = signature else { fatalError() }
                            // Verify signature
                            let signatureError = self.verifySignature(signature, data: message, objectId: objectId, algorithm: algorithm)
                            if signatureError != nil {
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Invalid signature")
                                completion(.communicationError(ErrorMessage(title: "Invalid signature", text: "The private key on the YubiKey does not match the certificate.")))
                                return
                            }
                            
                            YubiKitManager.shared.stopNFCConnection(withMessage: "Successfully signed data")
                            
                            print(signature.hex)
                            
                            if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") {
                                print("Save data to userDefaults...")
                                userDefaults.setValue(signature, forKey: "signedData")
                                completion(nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func cancel() {
        if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") {
            print("Save canceledByUser to userDefaults...")
            userDefaults.setValue(true, forKey: "canceledByUser")
        }
    }
    
    private func verifySignature(_ signature: Data, data: Data, objectId: String, algorithm: SecKeyAlgorithm) -> Error? {
        guard let certificate = TokenCertificateStorage().getTokenCertificate(withObjectId: objectId) else { return "No certificate for objectId: \(objectId)" }
        guard let publicKey = certificate.publicKey() else { return "No public key in this certificate" }
        var error: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(publicKey, algorithm, data as CFData, signature as CFData, &error);
        if !result {
            return "Signature verification failed"
        }
        if let error = error {
            return error.takeRetainedValue() as Error
        } else {
            return nil
        }
    }
}

@available(iOS 14.0, *)
private extension YKFPIVSession {
    func slotForObjectId(_ objectId: String, completion: @escaping (YKFPIVSlot?, TokenRequestViewModel.TokenError?) -> Void) {
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
                            let tokenError = TokenRequestViewModel.TokenError.communicationError(TokenRequestViewModel.ErrorMessage(title: "Communication error", text: apduError.localizedDescription))
                            completion(nil, tokenError)
                        } else {
                            let tokenError = TokenRequestViewModel.TokenError.missingCertificate(TokenRequestViewModel.ErrorMessage(title: "Missing certificate", text: "There is no matching certificate on this YubiKey."))
                            completion(nil, tokenError)
                        }
                    }
                }
            }
        }
    }
}

private extension Dictionary where Key == AnyHashable, Value: Any {
    func data() -> Data? {
        return self["data"] as? Data
    }
    
    func objectId() -> String? {
        return self["keyObjectID"] as? String
    }
    
    func keyType() -> YKFPIVKeyType? {
        guard let rawValue = self["keyType"] as? UInt, let keyType = YKFPIVKeyType(rawValue: rawValue) else { return nil }
        return keyType
    }
    
    func algorithm() -> SecKeyAlgorithm? {
        guard let rawValue = self["algorithm"] as? String else { return nil }
        return SecKeyAlgorithm(rawValue: rawValue as CFString)
    }
}

extension String: Error {}

