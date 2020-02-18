//
//  SecureStore.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/30/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

/*! Represents storage for secure information (e.g. user password/pin)
 Uses KeyChain as permanent storage
 */
class SecureStore {
    let secureStoreQueryable: SecureStoreQueryable
    
    public init(secureStoreQueryable: SecureStoreQueryable) {
        self.secureStoreQueryable = secureStoreQueryable
    }
    
    public func setValue(_ value: String, useBiometrics: Bool, for userAccount: String) throws {
        guard let encodedPassword = value.data(using: .utf8) else {
            throw SecureStoreError.string2DataConversionError
        }
        
        var query = secureStoreQueryable.setUpQuery(useBiometrics: useBiometrics)
        query[String(kSecAttrAccount)] = userAccount
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            var attributesToUpdate: [String: Any] = [:]
            attributesToUpdate[String(kSecValueData)] = encodedPassword
            
            status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            if status != errSecSuccess {
                throw error(from: status)
            }
            
        case errSecItemNotFound:
            query[String(kSecValueData)] = encodedPassword
            
            status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                throw error(from: status)
            }
            
        default:
            throw error(from: status)
        }
    }
    
    // getValue is asynchronous to avoid main thread blocking while scanning NFC and
    // validating password with device's biometric or passcode protection.
    public func getValueAsync(for userAccount: String, useBiometrics: Bool, success: @escaping (String) -> Void, failure: @escaping (Error) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var query = self.secureStoreQueryable.setUpQuery(useBiometrics: useBiometrics)
            query[String(kSecMatchLimit)] = kSecMatchLimitOne
            query[String(kSecReturnAttributes)] = kCFBooleanTrue
            query[String(kSecReturnData)] = kCFBooleanTrue
            query[String(kSecAttrAccount)] = userAccount
            
            var queryResult: AnyObject?
            let status = withUnsafeMutablePointer(to: &queryResult) {
                SecItemCopyMatching(query as CFDictionary, $0)
            }
            
            switch status {
            case errSecSuccess:
                guard let queriedItem = queryResult as? [String: Any],
                    let passwordData = queriedItem[String(kSecValueData)] as? Data,
                    let password = String(data: passwordData, encoding: .utf8)
                else {
                    failure(SecureStoreError.data2StringConversionError)
                    return
                }
                success(password)
                
            case errSecItemNotFound:
                failure(SecureStoreError.itemNotFound)
                
            default:
                failure(self.error(from: status))
            }
        }
    }
    
    public func hasValue(for userAccount: String) -> Bool {
        let status = self.getStatus(for: userAccount)
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed:
            return true
        default:
            return false
        }
    }
    
    public func hasValueProtected(for userAccount: String) -> Bool {
        let status = self.getStatus(for: userAccount)
        return status == errSecInteractionNotAllowed
    }
    
    private func getStatus(for userAccount: String) -> OSStatus {
        var query = secureStoreQueryable.setUpQuery(useBiometrics: false)
        query[String(kSecAttrAccount)] = userAccount
        query[String(kSecUseAuthenticationUI)] = kSecUseAuthenticationUIFail
        
        return SecItemCopyMatching(query as CFDictionary, nil)
    }
    
    public func removeValue(for userAccount: String) throws {
        var query = secureStoreQueryable.setUpQuery(useBiometrics: false)
        query[String(kSecAttrAccount)] = userAccount
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }
    
    public func removeAllValues() throws {
        let query = secureStoreQueryable.setUpQuery(useBiometrics: false)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }
    
    private func error(from status: OSStatus) -> SecureStoreError {
        var message: String
        if #available(iOS 11.3, *) {
            message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
        } else {
            // Fallback on earlier versions
            message = NSLocalizedString("Unhandled Error", comment: "")
        }
        return SecureStoreError.unhandledError(message: message)
    }
}

/*! Using this hex representation for keys that has format Data, when Store requires only String keys
 */
extension Data {
    var hex: String {
        return self.map { b in String(format: "%02X", b) }.joined()
    }
}
