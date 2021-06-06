//
//  SecCertificate+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import CommonCrypto

extension SecCertificate: Equatable {
    
    var commonName: String? {
        var name: CFString?
        SecCertificateCopyCommonName(self, &name)
        return name as String?
    }
    
    func tokenObjectId() -> String {
        let data = SecCertificateCopyData(self) as Data
        return data.sha256Hash().map { String(format: "%02X", $0) }.joined()
    }
    
    public static func ==(lhs: SecCertificate, rhs: SecCertificate) -> Bool {
        return lhs.tokenObjectId() == rhs.tokenObjectId()
    }
}
