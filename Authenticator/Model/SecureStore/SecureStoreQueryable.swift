//
//  SecureStoreQueryable.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/30/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation
import LocalAuthentication

/*!
 APP ID prefix required in case if we want to share storage with our other applications
 */
let APP_ID = "LQA3CS5MM7"

protocol SecureStoreQueryable {
    func setUpQuery(useAuthentication: Bool) -> [String: Any]
}

/*! Provides simple query to KeyChain specifically for password type of information
 where service is application or web site that password works with.
 Reusing the same name as our Applets on YubiKey have (e.g. OATH)
 Access group is currently not used,
 but potentially can be used if we planning to share this keychain with another application (e.g. YubiKey manager)
 */
public struct PasswordQueryable {
    let service: String
    let accessGroup: String?

    init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
}

extension PasswordQueryable: SecureStoreQueryable {
    func setUpQuery(useAuthentication: Bool) -> [String: Any] {
        var query: [String: Any] = [:]
        query[String(kSecClass)] = kSecClassGenericPassword
        query[String(kSecAttrService)] = service
// Access group if target environment is not simulator
#if !targetEnvironment(simulator)
        if let accessGroup = accessGroup {
            query[String(kSecAttrAccessGroup)] = "\(APP_ID)." + accessGroup
        }

        if useAuthentication {
            query[String(kSecAttrAccessControl)] = SecAccessControlCreateWithFlags(nil, // use the default allocator
                                                                                   kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                                   .userPresence,
                                                                                   nil) // ignore any error
            let context = LAContext()
            // Number of seconds to wait between a device unlock with biometric and another biometric authentication request.
            // So, if the user opens our app within 10 seconds of unlocking the device, we not prompting the user for FaceID/TouchID again.
            context.touchIDAuthenticationAllowableReuseDuration = 10
            query[String(kSecUseOperationPrompt)] = "Authenticate to login to YubiKey."
            query[String(kSecUseAuthenticationContext)] = context
        }
#endif
        return query
    }
}
