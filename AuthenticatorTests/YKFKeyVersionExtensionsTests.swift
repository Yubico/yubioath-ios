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

import XCTest
import YubiKit
@testable import Authenticator

class YKFKeyVersionExtensionsTests: XCTestCase {

    func testMajor() throws {
        let lhs = YKFVersion(bytes: 4, minor: 1, micro: 1)
        let rhs = YKFVersion(bytes: 3, minor: 3, micro: 3)
        XCTAssert(lhs > rhs, "\(lhs) is not greater than \(rhs)!")
    }
    
    func testMinor() throws {
        let lhs = YKFVersion(bytes: 3, minor: 4, micro: 1)
        let rhs = YKFVersion(bytes: 3, minor: 1, micro: 4)
        XCTAssert(lhs > rhs, "\(lhs) is not greater than \(rhs)!")
    }
    
    func testMicro() throws {
        let lhs = YKFVersion(bytes: 3, minor: 1, micro: 4)
        let rhs = YKFVersion(bytes: 3, minor: 1, micro: 1)
        XCTAssert(lhs > rhs, "\(lhs) is not greater than \(rhs)!")
    }
    
    func testEqual() throws {
        let lhs = YKFVersion(bytes: 3, minor: 1, micro: 4)
        let rhs = YKFVersion(bytes: 3, minor: 1, micro: 4)
        XCTAssert(lhs == rhs, "\(lhs) is not equal to \(rhs)!")
    }

}
