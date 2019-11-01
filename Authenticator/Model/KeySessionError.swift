//
//  KeySessionError.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/5/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

enum KeySessionError : Error {
    case notSupported
    case noOathService
    case noResponse
    case timeout
    case invalidUri
    case invalidCredentialUri
}


extension KeySessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return NSLocalizedString("This version of iOS does not support operations with the YubiKey for Lightning nor over NFC", comment: "Not supported")
        case .noOathService:
            return NSLocalizedString("Plug-in your YubiKey for that operation", comment: "No service found")
        case .noResponse:
            return NSLocalizedString("Something went wrong and key doesn't respond", comment: "No response")
        case .invalidUri:
            return NSLocalizedString("This is an URL conforming to Key URI Format specs", comment: "Invalid Uri")
        case .timeout:
            return NSLocalizedString("The operation got timed out", comment: "Invalid Uri")
        case .invalidCredentialUri:
            return NSLocalizedString("Invalid URI format", comment: "Invalid Uri")
        }
    }
}
