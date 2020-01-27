//
//  LABiometryTypeExtension.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 1/24/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import Foundation
import LocalAuthentication

extension LABiometryType {
    var title: String {
        switch self {
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        default:
            return ""
        }
    }
}
