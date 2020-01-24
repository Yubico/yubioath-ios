//
//  BiometricExtension.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 1/24/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import Foundation
import LocalAuthentication

extension LAContext {
    
    enum BiometricType: Int {
        case none = 0
        case touchId
        case faceID
        
        var title: String {
            switch self {
            case .none:
                return ""
            case .touchId:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            }
        }
    }
    
    var biometricType: BiometricType {

        guard self.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            return .none
        }

        if #available(iOS 11.0, *) {
            switch self.biometryType {
            case .none:
                return .none
            case .touchID:
                return .touchId
            case .faceID:
                return .faceID
            }
        } else {
            return  self.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) ? .touchId : .none
        }
    }
}
