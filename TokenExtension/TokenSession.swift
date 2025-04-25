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
    
    enum OperationType: String {
        case signData = "signData"
        case decryptData = "decryptData"
    }

    func tokenSession(_ session: TKTokenSession, beginAuthFor operation: TKTokenOperation, constraint: Any) throws -> TKTokenAuthOperation {
        // Insert code here to create an instance of TKTokenAuthOperation based on the specified operation and constraint.
        // Note that the constraint was previously established when creating token configuration with keychain items.
        return TKTokenPasswordAuthOperation()
    }
    
    func tokenSession(_ session: TKTokenSession, supports operation: TKTokenOperation, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) -> Bool {
        switch operation {
            case .readData, .signData, .decryptData, .performKeyExchange:
                return true
            default:
                return false
        }
    }
    
    func tokenSession(_ session: TKTokenSession, sign dataToSign: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data {
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
    
    // Decryption
    func tokenSession(_ session: TKTokenSession, decrypt ciphertext: Data, keyObjectID: Any, algorithm: TKTokenKeyAlgorithm) throws -> Data {
        
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

        sendNotificationWithEncryptedData(ciphertext, keyObjectID: objectId, keyType: keyType, algorithm: secKeyAlgorithm)
        
        let loopEndTime = Date(timeIntervalSinceNow: 95)
        var runLoop = true
        while(runLoop) {
            Thread.sleep(forTimeInterval: 1)
            if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator"), let decryptedData = userDefaults.value(forKey: "decryptedData") as? Data {
                sessionEndTime = Date(timeIntervalSinceNow: -10)
                reset()
                return decryptedData
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
            userDefaults.removeObject(forKey: "decryptedData")
        }
    }
    
    private func cancelAllNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
    }
    
    // Send local notification with data to sign
    private func sendNotificationWithData(_ data: Data, keyObjectID: String, keyType: KeyType, algorithm: SecKeyAlgorithm) {
            cancelAllNotifications()
        let categoryID = OperationType.signData.rawValue
        let content = UNMutableNotificationContent()
        content.title = String(localized: "YubiKey required")
        content.body = String(localized: "Tap here to complete the request using your YubiKey.")
        content.categoryIdentifier = categoryID
        content.userInfo = ["operationType": categoryID, "data": data, "keyObjectID": keyObjectID, "algorithm": algorithm.rawValue, "keyType": keyType.rawValue];
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let show = UNNotificationAction(identifier: categoryID, title:  String(localized: "Launch Yubico Authenticator"), options: .foreground)
        let category = UNNotificationCategory(identifier: categoryID, actions: [show], intentIdentifiers: [])

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request)
    }
    
    // Send local notification with encryption data
    private func sendNotificationWithEncryptedData(_ cipherData: Data, keyObjectID: String, keyType: KeyType, algorithm: SecKeyAlgorithm) {
        cancelAllNotifications()
        let categoryID = OperationType.decryptData.rawValue
        let content = UNMutableNotificationContent()
        content.title = String(localized: "YubiKey required")
        content.body = String(localized: "Tap here to complete the decryption request using your YubiKey.")
        content.categoryIdentifier = categoryID
        content.userInfo = ["operationType": categoryID, "data": cipherData, "keyObjectID": keyObjectID, "algorithm": algorithm.rawValue, "keyType": keyType.rawValue];
        content.sound = UNNotificationSound.default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let show = UNNotificationAction(identifier: categoryID, title:  String(localized: "Launch Yubico Authenticator"), options: .foreground)
        let category = UNNotificationCategory(identifier: categoryID, actions: [show], intentIdentifiers: [])

        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(request)
    }
}

extension String: Error {}
