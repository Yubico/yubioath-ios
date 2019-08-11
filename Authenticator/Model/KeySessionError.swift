//
//  KeySessionError.swift
//  Authenticator
//
//  Created by Irina Makhalova on 8/5/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

enum KeySessionError : Error {
    case notPluggedIn
    case noOathService
    case noResponse
}

extension KeySessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notPluggedIn:
            return NSLocalizedString("Plug-in your YubiKey for that operation", comment: "No key present")
        case .noOathService:
            return NSLocalizedString("Make sure that OATH is enabled for this key", comment: "No OATH")
        case .noResponse:
            return NSLocalizedString("Something went wrong and key doesn't respond", comment: "No response")
        }
    }
}
