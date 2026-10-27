/// Copyright (c) 2018 Razeware LLC
/// Copyright (c) 2026 Kenzi Voyer
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.
///
/// https://www.raywenderlich.com/9240-keychain-services-api-tutorial-for-passwords-in-swift

import Foundation
import LocalAuthentication

/*! Represents storage for secure information (e.g. user password/pin)
 Uses KeyChain as permanent storage
 */
nonisolated final class SecureStore: Sendable {
    let secureStoreQueryable: SecureStoreQueryable
    
    public init(secureStoreQueryable: SecureStoreQueryable) {
        self.secureStoreQueryable = secureStoreQueryable
    }
    
    public func setValue(_ value: Data, useAuthentication: Bool, for userAccount: String) throws {
        var query = secureStoreQueryable.setUpQuery(useAuthentication: useAuthentication)
        query[String(kSecAttrAccount)] = userAccount
        
        var status = SecItemCopyMatching(query as CFDictionary, nil)
        
        switch status {
        case errSecSuccess:
            var attributesToUpdate: [String: Any] = [:]
            attributesToUpdate[String(kSecValueData)] = value
            
            status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            
            if status != errSecSuccess {
                throw error(from: status)
            }
            
        case errSecItemNotFound:
            query[String(kSecValueData)] = value
            
            status = SecItemAdd(query as CFDictionary, nil)
            if status != errSecSuccess {
                throw error(from: status)
            }
            
        default:
            throw error(from: status)
        }
    }
    
    public func setValue(_ value: String, useAuthentication: Bool, for userAccount: String) throws {
        guard let encodedPassword = value.data(using: .utf8) else {
            throw SecureStoreError.string2DataConversionError
        }
        
        var query = secureStoreQueryable.setUpQuery(useAuthentication: useAuthentication)
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
    
    /* getValue is asynchronous to avoid main thread blocking while scanning NFC and
    validating password with device's biometric or passcode protection.
    */
    @concurrent public func getValue(for userAccount: String) async throws -> Data {
        guard let data = try copyValueData(for: userAccount, useAuthentication: hasValueProtected(for: userAccount)) else {
            throw SecureStoreError.dataCastError
        }
        return data
    }
    
    @concurrent public func getValue(for userAccount: String) async throws -> String {
        try string(from: copyValueData(for: userAccount, useAuthentication: hasValueProtected(for: userAccount)))
    }
    
    @concurrent public func getValue(for userAccount: String, useAuthentication: Bool) async throws -> String {
        try string(from: copyValueData(for: userAccount, useAuthentication: useAuthentication))
    }
    
    private func string(from data: Data?) throws -> String {
        guard let data, let string = String(data: data, encoding: .utf8) else {
            throw SecureStoreError.data2StringConversionError
        }
        return string
    }
    
    /// Blocks while the user authenticates if the item is protected. Returns nil if the item has no data.
    private func copyValueData(for userAccount: String, useAuthentication: Bool) throws -> Data? {
        var query = secureStoreQueryable.setUpQuery(useAuthentication: useAuthentication)
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
            let queriedItem = queryResult as? [String: Any]
            return queriedItem?[String(kSecValueData)] as? Data
        case errSecItemNotFound:
            throw SecureStoreError.itemNotFound
        default:
            throw error(from: status)
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
    
    public func removeAllValues() throws {
        let query = secureStoreQueryable.setUpQuery(useAuthentication: false)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw error(from: status)
        }
    }
        
    private func getStatus(for userAccount: String) -> OSStatus {
        var query = secureStoreQueryable.setUpQuery(useAuthentication: false)
        query[String(kSecAttrAccount)] = userAccount
        let context = LAContext()
        context.interactionNotAllowed = true
        query[String(kSecUseAuthenticationContext)] = context
        return SecItemCopyMatching(query as CFDictionary, nil)
    }
    
    public func removeValue(for userAccount: String) throws {
        var query = secureStoreQueryable.setUpQuery(useAuthentication: false)
        query[String(kSecAttrAccount)] = userAccount
        
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
nonisolated extension Data {
    var hex: String {
        return self.map { b in String(format: "%02X", b) }.joined()
    }
}
