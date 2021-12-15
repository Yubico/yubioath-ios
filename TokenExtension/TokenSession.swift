//
//  TokenSession.swift
//  TokenExtension
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import CryptoTokenKit
import UserNotifications

class TokenSession: TKTokenSession, TKTokenSessionDelegate {
    
    var sessionEndTime = Date(timeIntervalSinceNow: -10) // create endTime in the passed to force recreation of endTime when signing start
    
    // These cases match the YKFPIVKeyType in the SDK
    enum KeyType: UInt8 {
        case rsa1024 = 0x06
        case rsa2048 = 0x07
        case eccp256 = 0x11
        case eccp384 = 0x14
        case unknown = 0x00
    }

    func tokenSession(_ session: TKTokenSession, beginAuthFor operation: TKTokenOperation, constraint: Any) throws -> TKTokenAuthOperation {
        // Insert code here to create an instance of TKTokenAuthOperation based on the specified operation and constraint.
        // Note that the constraint was previously established when creating token configuration with keychain items.
        
        return YubikeyPinOperation()
    }
    
    func tokenSession(_ session: TKTokenSession, supports operation: TKTokenOperation, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) -> Bool {
        return operation == .signData
    }
    
    func tokenSession(_ session: TKTokenSession, sign dataToSign: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data {
        if YubiKeyPIVSession.shared.yubiKeyConnected {
            if YubiKeyPIVSession.shared.pinVerified {
                // sign the data here
            } else {
                throw TKError(.authenticationNeeded)
            }
        }
              
              
        // tokenSession() gets called multiple times even if we throw an error. This kludge make sure we only pop one notification.
        
        // if we're not passed sessionEndTime throw error and cancel all notifications
        if sessionEndTime.timeIntervalSinceNow > 0 {
            cancelAllNotifications()
            throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue, userInfo: nil)
        }

        // if we're past sessionEndTime set a new endtime and reset
        if sessionEndTime.timeIntervalSinceNow < 0 {
            reset()
            sessionEndTime = Date(timeIntervalSinceNow: 100)
        }
        
        guard let key = try? session.token.configuration.key(for: keyObjectID), let objectId = keyObjectID as? String else {
            throw "No key for you!"
        }
        
        var possibleKeyType: KeyType? = nil
        if key.keyType == kSecAttrKeyTypeRSA as String {
            if key.keySizeInBits == 1024 {
                possibleKeyType = .rsa1024
            } else if key.keySizeInBits == 2048 {
                possibleKeyType = .rsa2048
            }
        } else if key.keyType == kSecAttrKeyTypeECSECPrimeRandom as String {
            if key.keySizeInBits == 256 {
                possibleKeyType = .eccp256
            } else if key.keySizeInBits == 384 {
                possibleKeyType = .eccp384
            }
        }
        
        guard let keyType = possibleKeyType, let secKeyAlgorithm = algorithm.secKeyAlgorithm else {
            throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue, userInfo: nil)
        }

        sendNotificationWithData(dataToSign, keyObjectID: objectId, keyType: keyType, algorithm: secKeyAlgorithm)
        
        let loopEndTime = Date(timeIntervalSinceNow: 95)
        var runLoop = true
        while(runLoop) {
            Thread.sleep(forTimeInterval: 1)
            if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator"), let signedData = userDefaults.value(forKey: "signedData") as? Data {
                sessionEndTime = Date(timeIntervalSinceNow: -10)
                reset()
                return signedData
            }
            if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator"), let _ = userDefaults.value(forKey: "canceledByUser") {
                sessionEndTime = Date(timeIntervalSinceNow: 3)
                reset()
                throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue, userInfo: nil)
            }

            if loopEndTime < Date() {
                runLoop = false
            }
        }
        reset()
        throw NSError(domain: TKErrorDomain, code: TKError.Code.canceledByUser.rawValue, userInfo: nil)
    }
    
    func tokenSession(_ session: TKTokenSession, decrypt ciphertext: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data {
        var plaintext: Data?
        
        // Insert code here to decrypt the ciphertext using the specified key and algorithm.
        plaintext = nil
        
        if let plaintext = plaintext {
            return plaintext
        } else {
            // If the operation failed for some reason, fill in an appropriate error like objectNotFound, corruptedData, etc.
            // Note that responding with TKErrorCodeAuthenticationNeeded will trigger user authentication after which the current operation will be re-attempted.
            throw NSError(domain: TKErrorDomain, code: TKError.Code.authenticationNeeded.rawValue, userInfo: nil)
        }
    }
    
    func tokenSession(_ session: TKTokenSession, performKeyExchange otherPartyPublicKeyData: Data, keyObjectID objectID: Any, algorithm: TKTokenKeyAlgorithm, parameters: TKTokenKeyExchangeParameters) throws -> Data {
        var secret: Data?
        
        // Insert code here to perform Diffie-Hellman style key exchange.
        secret = nil
        
        if let secret = secret {
            return secret
        } else {
            // If the operation failed for some reason, fill in an appropriate error like objectNotFound, corruptedData, etc.
            // Note that responding with TKErrorCodeAuthenticationNeeded will trigger user authentication after which the current operation will be re-attempted.
            throw NSError(domain: TKErrorDomain, code: TKError.Code.authenticationNeeded.rawValue, userInfo: nil)
        }
    }
    
    private func reset() {
        cancelAllNotifications()
        if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") {
            userDefaults.removeObject(forKey: "canceledByUser")
            userDefaults.removeObject(forKey: "signedData")
        }
    }
    
    private func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
    
    private func sendNotificationWithData(_ data: Data, keyObjectID: String, keyType: KeyType, algorithm: SecKeyAlgorithm) {
        cancelAllNotifications()
        let categoryID = "SignData"
        let content = UNMutableNotificationContent()
        content.title = "YubiKey required"
        content.body = "Tap here to complete the request using your YubiKey."
        content.categoryIdentifier = categoryID
        content.userInfo = ["data": data, "keyObjectID": keyObjectID, "algorithm": algorithm.rawValue, "keyType": keyType.rawValue];
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let show = UNNotificationAction(identifier: categoryID, title: "Launch Yubico Authenticator", options: .foreground)
        let category = UNNotificationCategory(identifier: categoryID, actions: [show], intentIdentifiers: [])

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request)
    }
}

extension String: Error {}
