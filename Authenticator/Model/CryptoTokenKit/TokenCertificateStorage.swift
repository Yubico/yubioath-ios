/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
import CryptoTokenKit

@available(iOS 14.0, *)
struct TokenCertificateStorage {
    
    enum TokenCertificateStorageError: Error {
        case failedCreatingTokenKeychainCertificate
        case failedCreatingTokenKeychainKey
        case missingDriverConfigurartion
    }

    func storeTokenCertificate(certificate: SecCertificate) -> Error? {

        let label = certificate.tokenObjectId()
        
        // Create token keychain certificate using the certificate and derived label
        guard let tokenKeychainCertificate = TKTokenKeychainCertificate(certificate: certificate, objectID: label) else {
            return TokenCertificateStorageError.failedCreatingTokenKeychainCertificate
        }

        guard let tokenKeychainKey = TKTokenKeychainKey(certificate: certificate, objectID: label) else {
            return TokenCertificateStorageError.failedCreatingTokenKeychainKey
        }
        tokenKeychainKey.label = label
        tokenKeychainKey.canSign = true
        tokenKeychainKey.isSuitableForLogin = true

        // TODO: figure out when there might be multiple driverConfigurations and how to handle it
        guard let tokenDriverConfiguration = TKTokenDriver.Configuration.driverConfigurations.first?.value else {
            return TokenCertificateStorageError.missingDriverConfigurartion
        }
        let tokenConfiguration = tokenDriverConfiguration.addTokenConfiguration(for: label)
        tokenConfiguration.keychainItems.append(contentsOf: [tokenKeychainCertificate, tokenKeychainKey])
        return nil
    }
    
    func getTokenCertificate(withObjectId objectId: String) -> SecCertificate? {
        let certificates = listTokenCertificates()
        return certificates.first { certificate in
            return certificate.tokenObjectId() == objectId
        }
    }
    
    func listTokenCertificates() -> [SecCertificate] {
        guard let tokenDriverConfiguration = TKTokenDriver.Configuration.driverConfigurations.first?.value else { return [SecCertificate]() }
        let certificates = tokenDriverConfiguration.tokenConfigurations
            .map { $0.value }
            .flatMap { $0.keychainItems }
            .compactMap { $0 as? TKTokenKeychainCertificate }
            .map { SecCertificateCreateWithData(nil, $0.data as CFData) }
            .compactMap { $0 }
            .sorted { $0.commonName ?? "" < $1.commonName ?? "" }
        return certificates
    }

    func removeTokenCertificate(certificate: SecCertificate) -> Bool {
        guard let tokenDriverConfiguration = TKTokenDriver.Configuration.driverConfigurations.first?.value else { return false }
        tokenDriverConfiguration.removeTokenConfiguration(for: certificate.tokenObjectId() )
        return true
    }
}
