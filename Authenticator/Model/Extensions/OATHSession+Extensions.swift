/*
 * Copyright (C) Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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

import CryptoKit
import CryptoTokenKit
import Foundation
import YubiKit

extension YubiKitOATHSession {
    func calculateSteamTOTP(credential: Credential) async throws -> (code: String, validity: DateInterval) {
        let timestamp = Date().addingTimeInterval(10)
        let period = credential.type.period ?? 30
        let value = UInt64(timestamp.timeIntervalSince1970 / period)
        let challenge = withUnsafeBytes(of: value.bigEndian) { Data($0) }

        let response = try await calculateCredentialResponse(for: credential.id, challenge: challenge)

        let offset = Int(response.last! & 0x0F)
        let subdata = response.subdata(in: offset..<Int(offset + 4))
        let steamChars = Array("23456789BCDFGHJKMNPQRTVWXY")
        var number = UInt32(bigEndian: subdata.uint32 ?? 0) & 0x7fffffff
        var steamCode = ""
        for _ in 0...4 {
            steamCode.append(steamChars[Int(number) % steamChars.count])
            number /= UInt32(steamChars.count)
        }
        let startDate = Date(timeIntervalSince1970: TimeInterval(Int(timestamp.timeIntervalSince1970) - Int(timestamp.timeIntervalSince1970) % 30))
        let validity = DateInterval(start: startDate, duration: 30)
        return (steamCode, validity)
    }
}

extension YubiKitOATHSession.Code {
    var otp: OATHSession.OTP {
        // HOTP codes are valid until the next one is calculated.
        let end = validTo.timeIntervalSince1970.isFinite ? validTo : .distantFuture
        return OATHSession.OTP(code: code, validity: DateInterval(start: validFrom, end: end))
    }
}

enum OATHCredentialId {
    /// The identifier of a credential on the YubiKey, e.g. "60/Issuer:account".
    static func key(accountName: String, issuer: String?, period: UInt, isTOTP: Bool) -> String {
        var key = ""
        if isTOTP && period != 30 {
            key.append("\(period)/")
        }
        if let issuer, !issuer.isEmpty {
            key.append("\(issuer):")
        }
        key.append(accountName)
        return key
    }
}

extension SmartCardConnection {

    /// The OATH device id the way the Objective-C YubiKit computed it.
    ///
    /// Saved passwords are stored under this id. YubiKit derives `Credential.deviceId` from the same salt but
    /// encodes it differently, so the app selects the OATH application and computes it itself. Call this before
    /// creating an OATH session since selecting the application again locks it.
    func legacyOATHDeviceId() async throws -> String {
        let aid: [UInt8] = [0xa0, 0x00, 0x00, 0x05, 0x27, 0x21, 0x01]
        let select = Data([0x00, 0xa4, 0x04, 0x00, UInt8(aid.count)] + aid)
        let response = try await send(data: select)
        guard response.count >= 2, response.suffix(2) == Data([0x90, 0x00]),
              let records = TKBERTLVRecord.sequenceOfRecords(from: response.dropLast(2)),
              let salt = records.first(where: { $0.tag == 0x71 })?.value else {
            throw YubiKitOATHSessionError.responseParseError("Missing salt in OATH application select response", source: .here())
        }
        let hash = Data(SHA256.hash(data: salt))
        return String(hash.base64EncodedString().prefix(16)).replacingOccurrences(of: "=", with: "")
    }
}

// A struct of Sendable values (CredentialType, HashAlgorithm, Data, String, UInt8, Bool) that YubiKit
// doesn't declare Sendable.
extension YubiKitOATHSession.CredentialTemplate: @retroactive @unchecked Sendable {}

/// Errors from creating a credential template, with the messages the Objective-C YubiKit used.
enum CredentialTemplateError: Error, LocalizedError {
    case scheme, type, label, algorithm, counter, digits, period, missingSecret, invalidSecret, nameIssuerTooLong, issuerContainsColon

    var errorDescription: String? {
        switch self {
        case .scheme: return "Missing scheme in URL"
        case .type: return "Failed to get account type from URL"
        case .label: return "Missing account name"
        case .algorithm: return "Unknown algorithm"
        case .counter: return "Missing counter parameter"
        case .digits: return "Unsupported number of digits"
        case .period: return "Invalid period"
        case .missingSecret: return "Missing secret"
        case .invalidSecret: return "Invalid Base32 encoded secret"
        case .nameIssuerTooLong: return "Account name and issuer is to long"
        case .issuerContainsColon: return "Character ':' is not allowed in issuer"
        }
    }
}

extension YubiKitOATHSession.CredentialTemplate {

    struct Validation: OptionSet, Sendable {
        let rawValue: Int
        static let label = Validation(rawValue: 1 << 0)
        static let issuer = Validation(rawValue: 1 << 1)
    }

    /// Parses an otpauth:// URL the same way the Objective-C YubiKit did.
    /// - Parameter skip: Validations to skip, allowing an empty account name or a colon in the issuer.
    init(otpauthURL url: URL, skip: Validation = []) throws {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), components.scheme == "otpauth" else {
            throw CredentialTemplateError.scheme
        }
        func query(_ name: String) -> String? {
            components.queryItems?.first { $0.name == name }?.value
        }

        // Parse account name and issuer
        let path = components.path
        if !skip.contains(.label) && path.count < 2 {
            throw CredentialTemplateError.label
        }
        guard path.count >= 1 else { throw CredentialTemplateError.label }
        var name = String(path.dropFirst())
        var issuer = query("issuer")
        if name.contains(":") {
            var labelComponents = name.components(separatedBy: ":")
            issuer = labelComponents.removeFirst()
            name = labelComponents.joined(separator: ":")
        }

        let isTOTP: Bool
        switch components.host {
        case "hotp": isTOTP = false
        case "totp": isTOTP = true
        default: throw CredentialTemplateError.type
        }

        let algorithm: YubiKitOATHSession.HashAlgorithm
        switch query("algorithm") {
        case nil, "SHA1": algorithm = .sha1
        case "SHA256": algorithm = .sha256
        case "SHA512": algorithm = .sha512
        default: throw CredentialTemplateError.algorithm
        }

        let digits = query("digits").map { Int($0) ?? 0 } ?? 6

        let type: YubiKitOATHSession.CredentialType
        if isTOTP {
            let period = query("period").map { Int($0) ?? 0 } ?? 30
            type = .totp(period: TimeInterval(period))
        } else {
            guard let counter = query("counter") else { throw CredentialTemplateError.counter }
            type = .hotp(counter: UInt32(max(0, Int32(counter) ?? 0)))
        }

        guard let base32EncodedSecret = query("secret") else { throw CredentialTemplateError.missingSecret }
        guard let secret = Data(base32Encoded: base32EncodedSecret), !secret.isEmpty else {
            throw CredentialTemplateError.invalidSecret
        }

        try self.init(type: type, algorithm: algorithm, secret: secret, issuer: issuer, accountName: name, digits: digits, skip: skip)
    }

    /// Creates a template with the validation the Objective-C YubiKit did.
    init(type: YubiKitOATHSession.CredentialType,
         algorithm: YubiKitOATHSession.HashAlgorithm,
         secret: Data,
         issuer: String?,
         accountName: String,
         digits: Int,
         skip: Validation = []) throws {
        guard !secret.isEmpty else { throw CredentialTemplateError.missingSecret }
        guard [6, 7, 8].contains(digits) else { throw CredentialTemplateError.digits }
        // A zero or negative period traps when converted to UInt below and when YubiKit calculates a code.
        if let period = type.period, period <= 0 { throw CredentialTemplateError.period }
        if !skip.contains(.issuer), let issuer, issuer.contains(":") {
            throw CredentialTemplateError.issuerContainsColon
        }
        if !skip.contains(.label) && accountName.isEmpty {
            throw CredentialTemplateError.label
        }
        let key = OATHCredentialId.key(accountName: accountName, issuer: issuer, period: UInt(type.period ?? 0), isTOTP: type.period != nil)
        if !skip.contains(.label) && key.count > 64 {
            throw CredentialTemplateError.nameIssuerTooLong
        }
        // An empty issuer isn't part of the credential id on the YubiKey.
        let issuer = issuer?.isEmpty == true ? nil : issuer
        self.init(type: type, algorithm: algorithm, secret: secret, issuer: issuer, name: accountName, digits: UInt8(digits))
    }
}

extension Data {
    /// Decodes RFC 4648 Base32, ignoring case and padding, the same way the Objective-C YubiKit did.
    init?(base32Encoded string: String) {
        guard string.allSatisfy({ ("A"..."Z").contains($0) || ("a"..."z").contains($0) || ("2"..."7").contains($0) || $0 == "=" }) else {
            return nil
        }
        var bytes = [UInt8]()
        var buffer: UInt32 = 0
        var bits = 0
        for character in string.uppercased().unicodeScalars where character != "=" {
            let value: UInt32
            switch character {
            case "A"..."Z": value = character.value - UnicodeScalar("A").value
            default: value = character.value - UnicodeScalar("2").value + 26
            }
            buffer = (buffer << 5) | value
            bits += 5
            if bits >= 8 {
                bits -= 8
                bytes.append(UInt8((buffer >> UInt32(bits)) & 0xff))
            }
        }
        self.init(bytes)
    }
}
