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
}

extension KeySessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return NSLocalizedString("This version of iOS does not support operations with the YubiKey for Lightning", comment: "Not supported")
        case .noOathService:
            return NSLocalizedString("Plug-in your YubiKey for that operation", comment: "No service found")
        case .noResponse:
            return NSLocalizedString("Something went wrong and key doesn't respond", comment: "No response")
        }
    }
}
