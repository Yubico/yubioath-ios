//
//  AuthenticationTypeEnum.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 1/24/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import Foundation

enum AuthenticationType {
    case touchId
    case faceId
    case passcode
    case none
    
    var title: String {
        switch self {
        case .touchId:
            return "Touch ID"
        case .faceId:
            return "Face ID"
        case .passcode:
            return "Passcode"
        default:
            return ""
        }
    }
}
