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

enum KeySessionError : Error {
    case notSupported
    case noService
    case noResponse
    case timeout
    case invalidUri
    case invalidCredentialUri
}


extension KeySessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notSupported:
            return NSLocalizedString("This version of iOS does not support operations with the YubiKey for Lightning nor over NFC", comment: "Not supported")
        case .noService:
            return NSLocalizedString("Plug-in your YubiKey for that operation", comment: "No service found")
        case .noResponse:
            return NSLocalizedString("Something went wrong and key doesn't respond", comment: "No response")
        case .invalidUri:
            return NSLocalizedString("This QR code is not supported", comment: "Invalid Uri format, not OATH URL")
        case .timeout:
            return NSLocalizedString("The key doesn't respond", comment: "Timeout issue")
        case .invalidCredentialUri:
            return NSLocalizedString("Invalid URI format", comment: "Invalid Uri, wrong parameters")
        }
    }
}
