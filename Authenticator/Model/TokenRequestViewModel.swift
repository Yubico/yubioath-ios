/*
 * Copyright (C) 2022 Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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


import CommonCrypto
import CryptoKit
import OSLog
import YubiKit

extension PIV.VerifyPinResult {
    var tokenError: TokenRequestViewModel.TokenError? {
        switch self {
        case .success:
            return nil
        case .fail:
            return .wrongPassword(TokenRequestViewModel.ErrorMessage(title: String(localized: "Wrong PIN code", comment: "PIV extension wrong pin"), text: nil))
        case .pinLocked:
            return .passwordLocked(TokenRequestViewModel.ErrorMessage(title: String(localized: "Your PIN has ben blocked", comment: "PIV extension pin blocked title"),
                                                                      text: String(localized: "Use your PUK code to reset PIN.", comment: "PIV extension pin blocked text")))
        }
    }
}

final class TokenRequestViewModel {

    enum TokenError: Error {
        case wrongPassword(ErrorMessage)
        case passwordLocked(ErrorMessage)
        case notHandled(ErrorMessage)
        case missingCertificate(ErrorMessage)
        case communicationError(ErrorMessage)
        case alreadyHandled
        case cancelled

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
            case .cancelled:
                return ErrorMessage(title: "Cancelled", text: nil)
            }
        }
    }

    struct ErrorMessage {
        var title: String
        var text: String?
    }

    var operationCompleted = false
    private var wiredConnectionsTask: Task<Void, Never>?

    init() {
        Logger.allocation.debug("TokenRequestViewModel: init")
    }

    deinit {
        wiredConnectionsTask?.cancel()
        Logger.allocation.debug("TokenRequestViewModel: deinit")
    }

    /// Calls the handler when a wired YubiKey is inserted or removed, until ``stop()``.
    func isWiredKeyConnected(handler: @escaping @MainActor (Bool) -> Void) {
        wiredConnectionsTask?.cancel()
        wiredConnectionsTask = Task {
            for await connection in ConnectionManager.shared.wiredConnections() {
                handler(connection != nil)
            }
        }
    }

    func stop() {
        wiredConnectionsTask?.cancel()
        wiredConnectionsTask = nil
    }

    /// Throws ``TokenError/cancelled`` when there is nothing to show the user.
    func handleTokenRequest(_ userInfo: [AnyHashable: Any], password: String) async throws(TokenError) {
        Logger.ctk.yubilog("App: handleTokenRequest started")
        guard let operationType = userInfo.operationType() else { Logger.ctk.error("No OperationType defined"); throw .cancelled }
        guard let keyType = userInfo.keyType(),
              let objectId = userInfo.objectId(),
              let algorithm = userInfo.algorithm(),
              let message = userInfo.data() else { Logger.ctk.error("No data to sign"); throw .cancelled }
        let session: PIVSession
        let isNFCConnection: Bool
        do {
            let connection = try await ConnectionManager.shared.anyConnection()
            Logger.ctk.yubilog("App: got connection")
            isNFCConnection = connection.isNFC
            session = try await connection.pivSession()
        } catch where error.isNFCCancelledByUser {
            throw .cancelled
        } catch {
            Logger.ctk.error("No session: \(error)")
            let errorMessage = ErrorMessage(title: "Communication error", text: LocalizedErrorWrapper(error: error).localizedDescription)
            ConnectionManager.shared.closeNFC(errorMessage: errorMessage.title)
            throw .communicationError(errorMessage)
        }

        Logger.ctk.yubilog("App: got PIV session, searching for slot")
        let slot: PIV.Slot
        do {
            slot = try await session.slot(forObjectId: objectId)
        } catch let error as TokenError {
            ConnectionManager.shared.closeNFC(errorMessage: error.message.title)
            throw error
        } catch {
            let errorMessage = ErrorMessage(title: "Communication error", text: LocalizedErrorWrapper(error: error).localizedDescription)
            ConnectionManager.shared.closeNFC(errorMessage: errorMessage.title)
            throw .communicationError(errorMessage)
        }

        Logger.ctk.yubilog("App: found slot, verifying PIN")
        let verifyResult: PIV.VerifyPinResult
        do {
            verifyResult = try await session.verifyPin(password)
            Logger.ctk.yubilog("App: PIN verified, result: \(String(describing: verifyResult))")
        } catch {
            let tokenError = TokenError.notHandled(ErrorMessage(title: LocalizedErrorWrapper(error: error).localizedDescription, text: nil))
            ConnectionManager.shared.closeNFC(errorMessage: tokenError.message.title)
            throw tokenError
        }
        if let tokenError = verifyResult.tokenError {
            ConnectionManager.shared.closeNFC(errorMessage: tokenError.message.title)
            if case .wrongPassword = tokenError, isNFCConnection {
                throw .alreadyHandled
            } else {
                throw tokenError
            }
        }

        switch operationType {
        case .signData:
            Logger.ctk.yubilog("App: starting signWithKey")
            let signature: Data
            do {
                signature = try await session.sign(message, in: slot, keyType: keyType, algorithm: algorithm)
                Logger.ctk.yubilog("App: signWithKey completed")
            } catch {
                if error.statusCode == 0x6a80 {
                    ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Invalid signature", comment: "PIV extension NFC invalid signature"))
                    throw .communicationError(ErrorMessage(title: String(localized: "Invalid signature", comment: "PIV extension NFC invalid signature"),
                                                           text: String(localized: "The private key on the YubiKey does not match the certificate or there is no private key stored on the YubiKey.", comment: "PIV extension NFC invalid signature no private key")))
                } else {
                    throw .communicationError(ErrorMessage(title: String(localized: "Signing failed", comment: "PIV extension signing failed error message"), text: LocalizedErrorWrapper(error: error).localizedDescription))
                }
            }
            // Verify signature
            let signatureError = self.verifySignature(signature, data: message, objectId: objectId, algorithm: algorithm)
            if signatureError != nil {
                ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Invalid signature", comment: "PIV extension invalid signature"))
                throw .communicationError(ErrorMessage(title: String(localized: "Invalid signature", comment: "PIV extension invalid signature"),
                                                       text: String(localized: "The private key on the YubiKey does not match the certificate.", comment: "PIV extension invalid signature message")))
            }

            ConnectionManager.shared.closeNFC(message: String(localized: "Successfully signed data", comment: "PIV extension NFC successfully signed data"))

            guard let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") else { throw .cancelled }
            Logger.ctk.yubilog("Writing signedData to UserDefaults")
            userDefaults.setValue(signature, forKey: "signedData")
            userDefaults.synchronize()
            Logger.ctk.yubilog("UserDefaults synchronized, operationCompleted = true")
            self.operationCompleted = true
        case .decryptData:
            let decryptedData: Data
            do {
                decryptedData = try await session.decrypt(message, in: slot, algorithm: algorithm)
            } catch {
                if error.statusCode == 0x6a80 {
                    ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Invalid decryption", comment: "PIV extension NFC invalid decryption"))
                    throw .communicationError(ErrorMessage(title: String(localized: "Invalid decryption", comment: "PIV extension NFC invalid decryption"),
                                                           text: String(localized: "The private key on the YubiKey does not match the certificate or there is no private key stored on the YubiKey.", comment: "PIV extension NFC invalid decryption no private key")))
                } else {
                    throw .communicationError(ErrorMessage(title: String(localized: "Decryption failed", comment: "PIV extension decryption failed error message"), text: LocalizedErrorWrapper(error: error).localizedDescription))
                }
            }

            ConnectionManager.shared.closeNFC(message: String(localized: "Successfully decrypted cipher data", comment: "PIV extension NFC successfully decrypted cipher data"))

            guard let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") else { throw .cancelled }
            Logger.ctk.yubilog("Writing decryptedData to UserDefaults")
            userDefaults.setValue(decryptedData, forKey: "decryptedData")
            userDefaults.synchronize()
            Logger.ctk.yubilog("UserDefaults synchronized, operationCompleted = true")
            self.operationCompleted = true
        }
    }

    func cancel() {
        guard !operationCompleted else {
            Logger.ctk.yubilog("Skipping cancel - operation already completed")
            return
        }
        if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") {
            Logger.ctk.yubilog("Saving canceledByUser to userDefaults")
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

enum OperationType: String {
    case signData = "signData"
    case decryptData = "decryptData"
}


extension TokenRequestViewModel {

    /// Returns whether Yubico OTP is enabled over USB on the next USB-C YubiKey, or nil on devices with a Lightning port.
    func isYubiOTPEnabledOverUSBC() async -> Bool? {
        // If this device has a lightning port return nil
        if DeviceCapabilities.supportsLightning {
            return nil
        }
        guard let connection = try? await ConnectionManager.shared.nextWiredConnection(),
              let deviceInfo = try? await connection.managementSession().getDeviceInfo() else {
            return false
        }
        return deviceInfo.config.isApplicationEnabled(.otp, over: .usb) && !SettingsConfig.isOTPOverUSBIgnored(deviceId: deviceInfo.serialNumber)
    }

    func disableOTP() async throws {
        let session = try await ConnectionManager.shared.nextWiredConnection().managementSession()
        let deviceInfo = try await session.getDeviceInfo()
        try await session.updateDeviceConfig(deviceInfo.config.disable(application: .otp, over: .usb), reboot: true)
    }

    func waitForKeyRemoval() async {
        if let connection = ConnectionManager.shared.wiredConnection {
            _ = await connection.waitUntilClosed()
        }
    }

    func ignoreThisKey() async throws {
        let deviceInfo = try await ConnectionManager.shared.nextWiredConnection().managementSession().getDeviceInfo()
        SettingsConfig.registerUSBCDeviceToIgnore(deviceId: deviceInfo.serialNumber)
    }
}

/// The type of the key in a PIV slot, as sent by the token extension.
enum TokenKeyType: UInt8 {
    case rsa1024 = 0x06
    case rsa2048 = 0x07
    case eccp256 = 0x11
    case eccp384 = 0x14
}

private extension PIVSession {

    func slot(forObjectId objectId: String) async throws -> PIV.Slot {
        for slot in PIV.Slot.allSlots {
            if let certificate = try await certificate(in: slot), certificate.tokenObjectId() == objectId {
                return slot
            }
        }
        throw TokenRequestViewModel.TokenError.missingCertificate(TokenRequestViewModel.ErrorMessage(title: "Missing certificate", text: "There is no matching certificate on this YubiKey."))
    }

    /// Signs with the padding or hash the SecKeyAlgorithm specifies, like the Objective-C YubiKit did.
    func sign(_ message: Data, in slot: PIV.Slot, keyType: TokenKeyType, algorithm: SecKeyAlgorithm) async throws -> Data {
        switch keyType {
        case .rsa1024, .rsa2048:
            let keySize: RSA.KeySize = keyType == .rsa1024 ? .bits1024 : .bits2048
            let padded = try PIVPadding.padRSA(message, keySizeInBits: keySize.rawValue, algorithm: algorithm)
            return try await sign(padded, in: slot, keyType: .rsa(keySize), using: .raw)
        case .eccp256, .eccp384:
            let curve: EC.Curve = keyType == .eccp256 ? .secp256r1 : .secp384r1
            let hash = PIVPadding.hashForECDSA(message, algorithm: algorithm)
            // Prehashed data is only truncated or padded to the key size.
            return try await sign(hash, in: slot, keyType: .ec(curve), using: .prehashed(.sha256))
        }
    }

    /// Decrypts and removes the padding the SecKeyAlgorithm specifies, like the Objective-C YubiKit did.
    func decrypt(_ encrypted: Data, in slot: PIV.Slot, algorithm: SecKeyAlgorithm) async throws -> Data {
        let decrypted = try await decrypt(encrypted, in: slot, using: .raw)
        return try PIVPadding.unpadRSA(decrypted, algorithm: algorithm)
    }
}

/// Applies and removes padding by letting Security do it with a throwaway key, so any SecKeyAlgorithm works.
nonisolated enum PIVPadding {

    static func padRSA(_ data: Data, keySizeInBits: Int, algorithm: SecKeyAlgorithm) throws -> Data {
        let (privateKey, publicKey) = try makeRSAKeyPair(keySizeInBits: keySizeInBits)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(privateKey, algorithm, data as CFData, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        guard let padded = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionRaw, signature, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return padded as Data
    }

    static func unpadRSA(_ data: Data, algorithm: SecKeyAlgorithm) throws -> Data {
        guard data.count == 1024 / 8 || data.count == 2048 / 8 else {
            throw "Failed to unpad RSA data - input buffer bad size."
        }
        let (privateKey, publicKey) = try makeRSAKeyPair(keySizeInBits: data.count * 8)
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(publicKey, .rsaEncryptionRaw, data as CFData, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        guard let decrypted = SecKeyCreateDecryptedData(privateKey, algorithm, encrypted, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return decrypted as Data
    }

    /// Hashes the message for the X9.62 message algorithms. Digests are passed through as is.
    static func hashForECDSA(_ data: Data, algorithm: SecKeyAlgorithm) -> Data {
        switch algorithm {
        case .ecdsaSignatureMessageX962SHA1: return Data(Insecure.SHA1.hash(data: data))
        case .ecdsaSignatureMessageX962SHA224:
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA224_DIGEST_LENGTH))
            data.withUnsafeBytes { _ = CC_SHA224($0.baseAddress, CC_LONG(data.count), &hash) }
            return Data(hash)
        case .ecdsaSignatureMessageX962SHA256: return Data(SHA256.hash(data: data))
        case .ecdsaSignatureMessageX962SHA384: return Data(SHA384.hash(data: data))
        case .ecdsaSignatureMessageX962SHA512: return Data(SHA512.hash(data: data))
        default: return data
        }
    }

    private static func makeRSAKeyPair(keySizeInBits: Int) throws -> (privateKey: SecKey, publicKey: SecKey) {
        let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: keySizeInBits]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw "Failed to get the public key"
        }
        return (privateKey, publicKey)
    }
}

private extension Dictionary where Key == AnyHashable, Value: Any {
    func data() -> Data? {
        return self["data"] as? Data
    }

    func objectId() -> String? {
        return self["keyObjectID"] as? String
    }

    func keyType() -> TokenKeyType? {
        guard let rawValue = self["keyType"] as? UInt8 ?? (self["keyType"] as? UInt).map({ UInt8(truncatingIfNeeded: $0) }) else { return nil }
        return TokenKeyType(rawValue: rawValue)
    }

    func algorithm() -> SecKeyAlgorithm? {
        guard let rawValue = self["algorithm"] as? String else { return nil }
        return SecKeyAlgorithm(rawValue: rawValue as CFString)
    }

    func operationType() -> OperationType? {
        guard let rawValue = self["operationType"] as? String else { return nil }
        return OperationType.init(rawValue: rawValue)
    }
}

extension String: @retroactive Error {}
