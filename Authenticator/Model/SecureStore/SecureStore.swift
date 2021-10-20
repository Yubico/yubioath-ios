/// Copyright (c) 2018 Razeware LLC
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

/*! Represents storage for secure information (e.g. user password/pin)
 Uses KeyChain as permanent storage
 */
class SecureStore {
    let secureStoreQueryable: SecureStoreQueryable
    
    public init(secureStoreQueryable: SecureStoreQueryable) {
        self.secureStoreQueryable = secureStoreQueryable
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
    public func getValue(for userAccount: String, completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let useAuthentication = self.hasValueProtected(for: userAccount)
            var query = self.secureStoreQueryable.setUpQuery(useAuthentication: useAuthentication)
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
                    completion(.failure(SecureStoreError.data2StringConversionError))
                    return
                }
                completion(.success(password))
            case errSecItemNotFound:
                completion(.failure(SecureStoreError.itemNotFound))
            default:
                completion(.failure(self.error(from: status)))
            }
        }
    }
    
    /* getValue is asynchronous to avoid main thread blocking while scanning NFC and
    validating password with device's biometric or passcode protection.
    */
    public func getValueAsync(for userAccount: String, useAuthentication: Bool, success: @escaping (String) -> Void, failure: @escaping (Error) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var query = self.secureStoreQueryable.setUpQuery(useAuthentication: useAuthentication)
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
        query[String(kSecUseAuthenticationUI)] = kSecUseAuthenticationUIFail
        
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
extension Data {
    var hex: String {
        return self.map { b in String(format: "%02X", b) }.joined()
    }
}
