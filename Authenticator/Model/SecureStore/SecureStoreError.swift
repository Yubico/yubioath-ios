//
//  SecureStoreError.swift
//  Authenticator
//
//  Created by Irina Makhalova on 10/1/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

public enum SecureStoreError: Error {
  case string2DataConversionError
  case data2StringConversionError
  case unhandledError(message: String)
}

/*! Represents type of errors that happen during communication with SecureStore
 */
extension SecureStoreError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .string2DataConversionError:
      return NSLocalizedString("String to Data conversion error", comment: "")
    case .data2StringConversionError:
      return NSLocalizedString("Data to String conversion error", comment: "")
    case .unhandledError(let message):
      return NSLocalizedString(message, comment: "")
    }
  }
}
