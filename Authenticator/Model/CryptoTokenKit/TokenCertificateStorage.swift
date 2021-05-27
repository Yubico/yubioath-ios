//
//  CryptoTokenStorage.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import CryptoTokenKit

@available(iOS 14.0, *)
struct TokenCertificateStorage {

    func storeTokenCertificate(certificate: SecCertificate) -> Bool {

        guard let label = certificate.tokenObjectId() else { return false }
        
        // Create token keychain certificate using the certificate and derived label
        guard let tokenKeychainCertificate = TKTokenKeychainCertificate(certificate: certificate, objectID: label) else { return false }

        guard let tokenKeychainKey = TKTokenKeychainKey(certificate: certificate, objectID: label) else { return false }
        tokenKeychainKey.label = label
        tokenKeychainKey.canSign = true
        tokenKeychainKey.isSuitableForLogin = true
        
//        var tokenOperationConstraints = [NSNumber: TKTokenOperationConstraint]()
//        tokenOperationConstraints[NSNumber(value: TKTokenOperation.signData.rawValue)] = "PIN" as TKTokenOperationConstraint
//        tokenKeychainKey.constraints = tokenOperationConstraints

        // TODO: figure out when there might be multiple driverConfigurations and how to handle it
        guard let tokenDriverConfiguration = TKTokenDriver.Configuration.driverConfigurations.first?.value else { return false }
        let tokenConfiguration = tokenDriverConfiguration.addTokenConfiguration(for: label)
        tokenConfiguration.keychainItems.append(contentsOf: [tokenKeychainCertificate, tokenKeychainKey])
        return true
    }
    
    func listTokenCertificates() -> [SecCertificate] {
        guard let tokenDriverConfiguration = TKTokenDriver.Configuration.driverConfigurations.first?.value else { return [SecCertificate]() }
        let certificates = tokenDriverConfiguration.tokenConfigurations
            .map { $0.value }
            .flatMap { $0.keychainItems }
            .compactMap { $0 as? TKTokenKeychainCertificate }
            .map { SecCertificateCreateWithData(nil, $0.data as CFData) }
            .compactMap { $0 }
        return certificates
    }

    func removeTokenCertificate(certificate: SecCertificate) -> Bool {
        guard let tokenDriverConfiguration = TKTokenDriver.Configuration.driverConfigurations.first?.value else { return false }
        guard let label = certificate.tokenObjectId() else { return false }
        tokenDriverConfiguration.removeTokenConfiguration(for: label)
        return true
    }
}
