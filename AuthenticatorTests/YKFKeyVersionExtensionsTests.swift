//
//  YKFKeyVersionExtensionsTests.swift
//  AuthenticatorTests
//
//  Created by Jens Utbult on 2020-05-14.
//  Copyright © 2020 Yubico. All rights reserved.
//

import XCTest
import YubiKit
@testable import Authenticator

class YKFKeyVersionExtensionsTests: XCTestCase {

    func testMajor() throws {
        let lhs = YKFKeyVersion(bytes: 4, minor: 1, micro: 1)
        let rhs = YKFKeyVersion(bytes: 3, minor: 3, micro: 3)
        XCTAssert(lhs > rhs, "\(lhs) is not greater than \(rhs)!")
    }
    
    func testMinor() throws {
        let lhs = YKFKeyVersion(bytes: 3, minor: 4, micro: 1)
        let rhs = YKFKeyVersion(bytes: 3, minor: 1, micro: 4)
        XCTAssert(lhs > rhs, "\(lhs) is not greater than \(rhs)!")
    }
    
    func testMicro() throws {
        let lhs = YKFKeyVersion(bytes: 3, minor: 1, micro: 4)
        let rhs = YKFKeyVersion(bytes: 3, minor: 1, micro: 1)
        XCTAssert(lhs > rhs, "\(lhs) is not greater than \(rhs)!")
    }
    
    func testEqual() throws {
        let lhs = YKFKeyVersion(bytes: 3, minor: 1, micro: 4)
        let rhs = YKFKeyVersion(bytes: 3, minor: 1, micro: 4)
        XCTAssert(lhs == rhs, "\(lhs) is not equal to \(rhs)!")
    }

}
