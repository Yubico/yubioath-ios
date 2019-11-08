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
  
  public func setValue(_ value: String, for userAccount: String) throws {
    guard let encodedPassword = value.data(using: .utf8) else {
      throw SecureStoreError.string2DataConversionError
    }
    
    var query = secureStoreQueryable.query
    query[String(kSecAttrAccount)] = userAccount
    
    var status = SecItemCopyMatching(query as CFDictionary, nil)
    
    switch status {
    case errSecSuccess:
      var attributesToUpdate: [String : Any] = [:]
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
  
  public func getValue(for userAccount: String) throws -> String? {
    var query = secureStoreQueryable.query
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
          throw SecureStoreError.data2StringConversionError
      }
      
      return password
      
    case errSecItemNotFound:
      return nil
      
    default:
      throw error(from: status)
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

extension SecureStore {
    static let DEFAULT_KEY = "defaultKey"
    
    public func setValue(_ value: String, for userAccount: String?) throws {
        try self.setValue(value, for: userAccount ?? SecureStore.DEFAULT_KEY)
    }
    
    public func moveValue(to userAccount: String) throws {
        // do nothing if we couldn't get stored password for default key
        // we will try on next successful attempt
        if let password = try? self.getValue(for: SecureStore.DEFAULT_KEY) {
            try self.setValue(password, for: userAccount)
            try? self.removeValue(for: SecureStore.DEFAULT_KEY)
        }
    }
}

/*! Using this hex representation for keys that has format Data, when Store requires only String keys
 */
extension Data {
    var hex: String {
        return self.map { b in String(format: "%02X", b) }.joined()
    }
}
