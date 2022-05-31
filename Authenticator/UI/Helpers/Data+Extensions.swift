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
