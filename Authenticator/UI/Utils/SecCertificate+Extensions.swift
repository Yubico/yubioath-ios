//
//  SecCertificate+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import CommonCrypto

extension SecCertificate {
    
    var commonName: String? {
        var name: CFString?
        SecCertificateCopyCommonName(self, &name)
        return name as String?
    }
    
    func tokenObjectId() -> String? {
        guard let name = self.commonName, let data = name.data(using: .utf8) else { return nil }
        return data.sha256Hash().map { String(format: "%02X", $0) }.joined()
    }
}
