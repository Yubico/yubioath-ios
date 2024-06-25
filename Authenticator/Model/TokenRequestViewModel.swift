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
extension Error {
    var tokenError: TokenRequestViewModel.TokenError {
        let code = YKFPIVErrorCode(rawValue: UInt((self as NSError).code))
        switch code {
        case .pinLocked:
            return .passwordLocked(TokenRequestViewModel.ErrorMessage(title: String(localized: "Your PIN has ben blocked", comment: "PIV extension pin blocked title"),
                                                                      text: String(localized: "Use your PUK code to reset PIN.", comment: "PIV extension pin blocked text")))
        case .invalidPin:
            return .wrongPassword(TokenRequestViewModel.ErrorMessage(title: String(localized: "Wrong PIN code", comment: "PIV extension wrong pin"), text: nil))
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
    
    var isWiredKeyConnectedHandler: ((Bool) -> Void)?
    var isYubiOTPEnabledHandler: ((Bool) -> Void)?

    func isWiredKeyConnected(handler: @escaping (Bool) -> Void) {
        isWiredKeyConnectedHandler = handler
        connection.smartCardConnection { [weak self] connection in
            DispatchQueue.main.async {
                self?.isWiredKeyConnectedHandler?(connection != nil)
            }
        }
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            connection.accessoryConnection { [weak self] connection in
                DispatchQueue.main.async {
                    self?.isWiredKeyConnectedHandler?(connection != nil)
                }
            }
        }
    }

    func handleTokenRequest(_ userInfo: [AnyHashable: Any], password: String, completion: @escaping (TokenError?) -> Void) {
        connection.startConnection { connection in
            connection.pivSession { session, error in
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
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Invalid signature", comment: "PIV extension NFC invalid signature"))
                                completion(.communicationError(ErrorMessage(title: String(localized: "Invalid signature", comment: "PIV extension NFC invalid signature"),
                                                                            text: String(localized: "The private key on the YubiKey does not match the certificate or there is no private key stored on the YubiKey.", comment: "PIV extension NFC invalid signature no private key"))))
                                return
                            }
                            if let error = error {
                                    completion(.communicationError(ErrorMessage(title: String(localized: "Signing failed", comment: "PIV extension signing failed error message"), text: error.localizedDescription)))
                                return
                            }
                            guard let signature = signature else { fatalError() }
                            // Verify signature
                            let signatureError = self.verifySignature(signature, data: message, objectId: objectId, algorithm: algorithm)
                            if signatureError != nil {
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Invalid signature", comment: "PIV extension invalid signature"))
                                completion(.communicationError(ErrorMessage(title: String(localized: "Invalid signature", comment: "PIV extension invalid signature"),
                                                                            text: String(localized: "The private key on the YubiKey does not match the certificate.", comment: "PIV extension invalid signature message"))))
                                return
                            }
                            
                            YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Successfully signed data", comment: "PIV extension NFC successfully signed data"))
                            
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


extension TokenRequestViewModel {
    
    func isYubiOTPEnabledOverUSBC(completion: @escaping (Bool?) -> Void) {
        isYubiOTPEnabledHandler = completion
        
        // If this device does not have a lightning port return nil
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            completion(nil)
            return
        }
        connection.smartCardConnection { [weak self] connection in
            connection?.managementSession { session, error in
                guard let session else { self?.isYubiOTPEnabledHandler?(false); return }
                session.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo, let configuration = deviceInfo.configuration else { self?.isYubiOTPEnabledHandler?(false); return }
                    guard !configuration.isEnabled(.OTP, overTransport: .USB) || SettingsConfig.isOTPOverUSBIgnored(deviceId: deviceInfo.serialNumber) else {
                        self?.isYubiOTPEnabledHandler?(true)
                        return
                    }
                    self?.isYubiOTPEnabledHandler?(false)
                }
            }
        }
    }
    
    func disableOTP(completion: @escaping (Error?) -> Void) {
        connection.smartCardConnection { connection in
            connection?.managementSession { session, error in
                guard let session else { completion(error); return }
                session.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo, let configuration = deviceInfo.configuration else { completion(error); return }
                    configuration.setEnabled(false, application: .OTP, overTransport: .USB)
                    session.write(configuration, reboot: true) { error in
                        completion(error)
                    }
                }
            }
        }
    }
    
    func waitForKeyRemoval(completion: @escaping () -> Void) {
        connection.didDisconnect { _, _ in
            completion()
        }
    }

    func ignoreThisKey(completion: @escaping (Error?) -> Void) {
        connection.smartCardConnection { connection in
            connection?.managementSession { session, error in
                guard let session else { completion(error); return }
                session.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo else { completion(error); return }
                    SettingsConfig.registerUSBCDeviceToIgnore(deviceId: deviceInfo.serialNumber)
                    completion(nil)
                }
            }
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

