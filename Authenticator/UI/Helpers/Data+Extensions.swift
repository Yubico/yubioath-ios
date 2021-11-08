//
//  Data+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import CryptoKit

extension Data {
    func sha256Hash() -> Data {
        let digest = SHA256.hash(data: self)
        let bytes = Array(digest.makeIterator())
        return Data(bytes)
    }
}

extension Data {
    var uint32: UInt32? {
        guard self.count == MemoryLayout<UInt32>.size else { return nil }
        return withUnsafeBytes { $0.load(as: UInt32.self) }
    }

    var uint64: UInt64? {
        guard self.count == MemoryLayout<UInt64>.size else { return nil }
        return withUnsafeBytes { $0.load(as: UInt64.self) }
    }
}
