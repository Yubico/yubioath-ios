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
