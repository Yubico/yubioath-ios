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

import Foundation
import Testing
import YubiKit
@testable import Authenticator

struct YubiKitExtensionsTests {

    @Test(arguments: [
        ("4.1.1", "3.3.3"),
        ("3.4.1", "3.1.4"),
        ("3.1.4", "3.1.1"),
    ])
    func versionComparison(newer: String, older: String) throws {
        let newer = try #require(Version(newer))
        let older = try #require(Version(older))
        #expect(newer > older)
    }

    @Test func versionEquality() throws {
        let version = try #require(Version("3.1.4"))
        #expect(version == Version("3.1.4"))
        #expect(Version("4.1.4") != version)
    }

    struct CredentialKeyCase: Sendable, CustomTestStringConvertible {
        let accountName: String
        let issuer: String?
        let period: UInt
        let isTOTP: Bool
        let expected: String
        var testDescription: String { expected }
    }

    @Test(arguments: [
        CredentialKeyCase(accountName: "alice", issuer: "Example", period: 30, isTOTP: true, expected: "Example:alice"),
        CredentialKeyCase(accountName: "alice", issuer: "Example", period: 60, isTOTP: true, expected: "60/Example:alice"),
        CredentialKeyCase(accountName: "alice", issuer: "", period: 60, isTOTP: true, expected: "60/alice"),
        CredentialKeyCase(accountName: "alice", issuer: nil, period: 0, isTOTP: false, expected: "alice"),
    ])
    func credentialKey(_ testCase: CredentialKeyCase) {
        let key = OATHCredentialId.key(accountName: testCase.accountName, issuer: testCase.issuer, period: testCase.period, isTOTP: testCase.isTOTP)
        #expect(key == testCase.expected)
    }

    // RFC 4648 test vectors, plus lowercase and missing padding which the old YubiKit accepted.
    @Test(arguments: [
        ("", Data()),
        ("MY======", Data("f".utf8)),
        ("MZXW6YTBOI======", Data("foobar".utf8)),
        ("mzxw6ytboi", Data("foobar".utf8)),
        ("MZXW6YTB0I", nil),
    ] as [(String, Data?)])
    func base32(encoded: String, decoded: Data?) {
        #expect(Data(base32Encoded: encoded) == decoded)
    }

    @Test func otpAuthURL() throws {
        let url = try #require(URL(string: "otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Ignored&algorithm=SHA256&digits=8&period=60"))
        let template = try YubiKitOATHSession.CredentialTemplate(otpauthURL: url)
        #expect(template.issuer == "Example")
        #expect(template.name == "alice@example.com")
        #expect(template.algorithm == .sha256)
        #expect(template.digits == 8)
        #expect(template.type.period == 60)
        #expect(template.identifier == "60/Example:alice@example.com")
    }

    @Test(arguments: [
        ("otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP", "Example", "alice@example.com"),
        ("otpauth://totp/Example:alice:work?secret=JBSWY3DPEHPK3PXP", "Example", "alice:work"),
    ])
    func otpAuthURLLabel(url: String, issuer: String, name: String) throws {
        let template = try YubiKitOATHSession.CredentialTemplate(otpauthURL: try #require(URL(string: url)))
        #expect(template.issuer == issuer)
        #expect(template.name == name)
    }

    @Test(arguments: [
        "otpauth://totp/?secret=JBSWY3DPEHPK3PXP",
        "otpauth://hotp/alice?secret=JBSWY3DPEHPK3PXP",
    ])
    func invalidOTPAuthURL(url: String) throws {
        let url = try #require(URL(string: url))
        #expect(throws: (any Error).self) {
            try YubiKitOATHSession.CredentialTemplate(otpauthURL: url)
        }
    }

    @Test func otpAuthURLWithoutLabelSkippingIssuerAndLabel() throws {
        let url = try #require(URL(string: "otpauth://totp/?secret=JBSWY3DPEHPK3PXP"))
        #expect(throws: Never.self) {
            try YubiKitOATHSession.CredentialTemplate(otpauthURL: url, skip: [.issuer, .label])
        }
    }

    @Test(arguments: [
        "otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP&period=0",
        "otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP&period=-1",
        "otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP&period=abc",
    ])
    func invalidPeriod(url: String) throws {
        let url = try #require(URL(string: url))
        #expect(throws: CredentialTemplateError.period) {
            try YubiKitOATHSession.CredentialTemplate(otpauthURL: url)
        }
        #expect(throws: CredentialTemplateError.period) {
            try YubiKitOATHSession.CredentialTemplate(otpauthURL: url, skip: [.issuer, .label])
        }
    }

    @Test func hotpCounter() throws {
        let url = try #require(URL(string: "otpauth://hotp/alice?secret=JBSWY3DPEHPK3PXP&counter=5"))
        let template = try YubiKitOATHSession.CredentialTemplate(otpauthURL: url)
        #expect(template.type.counter == 5)
    }

    @Test func ecdsaHash() {
        let message = Data("hello".utf8)
        #expect(PIVPadding.hashForECDSA(message, algorithm: .ecdsaSignatureMessageX962SHA256).count == 32)
        #expect(PIVPadding.hashForECDSA(message, algorithm: .ecdsaSignatureMessageX962SHA224).count == 28)
        #expect(PIVPadding.hashForECDSA(message, algorithm: .ecdsaSignatureDigestX962SHA256) == message)
    }

    @Test func rsaPaddingRoundTrip() throws {
        let message = Data("hello".utf8)
        let padded = try PIVPadding.padRSA(message, keySizeInBits: 1024, algorithm: .rsaSignatureMessagePKCS1v15SHA256)
        #expect(padded.count == 128)
        // PKCS#1 v1.5 signature padding starts with 00 01 FF.
        #expect(Array(padded.prefix(3)) == [0x00, 0x01, 0xff])
    }
}
