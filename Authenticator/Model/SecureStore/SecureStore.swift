//
//  SecureStore.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/30/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation
import LocalAuthentication

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
        
        var query = secureStoreQueryable.query
        query[String(kSecAttrAccount)] = userAccount
        
        if useBiometrics {
            query[String(kSecAttrAccessControl)] = SecAccessControlCreateWithFlags(
                nil, // use the default allocator
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                .userPresence,
                nil) // ignore any error
            let context = LAContext()
            // Number of seconds to wait between a device unlock with biometric and another biometric authentication request.
            // So, if the user opens our app within 10 seconds of unlocking the device, we not prompting the user for FaceID/TouchID again.
            context.touchIDAuthenticationAllowableReuseDuration = 10
            query[String(kSecUseAuthenticationContext)] = context
        }
        
        print("Set Value Bla bla bla \(useBiometrics)")
        
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
    
    public func getValueAsync(for userAccount: String, useBiometrics: Bool, success: ((String?) -> Void)?, failure: ((Error?) -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var query = self.secureStoreQueryable.query
            query[String(kSecMatchLimit)] = kSecMatchLimitOne
            query[String(kSecReturnAttributes)] = kCFBooleanTrue
            query[String(kSecReturnData)] = kCFBooleanTrue
            query[String(kSecAttrAccount)] = userAccount
            
            if useBiometrics {
                query[String(kSecAttrAccessControl)] = SecAccessControlCreateWithFlags(
                    nil, // use the default allocator
                    kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                    .userPresence,
                    nil) // ignore any error
                let context = LAContext()
                // Number of seconds to wait between a device unlock with biometric and another biometric authentication request.
                // So, if the user opens our app within 10 seconds of unlocking the device, we not prompting the user for FaceID/TouchID again.
                context.touchIDAuthenticationAllowableReuseDuration = 10
                query[String(kSecUseAuthenticationContext)] = context
            }
            
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
                    failure?(SecureStoreError.data2StringConversionError)
                    return
                }
                success?(password)
                
            case errSecItemNotFound:
                success?(nil)
                
            default:
                failure?(self.error(from: status))
            }
        }
    }
    
    public func removeValue(for userAccount: String) throws {
        var query = secureStoreQueryable.query
        query[String(kSecAttrAccount)] = userAccount
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }
    
    public func removeAllValues() throws {
        let query = secureStoreQueryable.query
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
