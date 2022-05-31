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

@testable import Authenticator

class SecureStoreTests: XCTestCase {
    var secureStoreWithGenericPwd: SecureStore!
    
    override func setUp() {
        super.setUp()
        
        let genericPwdQueryable = PasswordQueryable(service: "someService")
        secureStoreWithGenericPwd = SecureStore(secureStoreQueryable: genericPwdQueryable)
    }
    
    override func tearDown() {
        try? secureStoreWithGenericPwd.removeAllValues()
        
        super.tearDown()
    }
    
    func testSaveGenericPassword() {
        do {
            try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
        } catch let e {
            XCTFail("Saving generic password failed with \(e.localizedDescription).")
        }
    }
    
    func testReadGenericPassword() {
        do {
            var password = ""
            let expectation = self.expectation(description: "Get password")
            
            try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
            secureStoreWithGenericPwd.getValueAsync(for: "genericPassword", useAuthentication: false, success: { p in
                password = p
                expectation.fulfill()
            }, failure: { _ in
                expectation.fulfill()
            })
            
            waitForExpectations(timeout: 5.0, handler: nil)
            XCTAssertEqual("pwd_1234", password)
            
        } catch let e {
            XCTFail("Reading generic password failed with \(e.localizedDescription).")
        }
    }
    
    func testUpdateGenericPassword() {
        do {
            var password = ""
            let expectation = self.expectation(description: "Get password")
            
            try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
            try secureStoreWithGenericPwd.setValue("pwd_updated123", useAuthentication: false, for: "genericPassword")
            secureStoreWithGenericPwd.getValueAsync(for: "genericPassword", useAuthentication: false, success: { p in
                password = p
                expectation.fulfill()
            }, failure: { _ in
                expectation.fulfill()
            })
            
            waitForExpectations(timeout: 5.0, handler: nil)
            XCTAssertEqual("pwd_updated123", password)
        } catch let e {
            XCTFail("Updating generic password failed with \(e.localizedDescription).")
        }
    }
    
    func testRemoveGenericPassword() {
        do {
            var password: String?
            let expectation = self.expectation(description: "Get password")
            
            try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
            try secureStoreWithGenericPwd.removeValue(for: "genericPassword")
            secureStoreWithGenericPwd.getValueAsync(for: "genericPassword", useAuthentication: false, success: { p in
                password = p
                expectation.fulfill()
            }, failure: { _ in
                password = nil
                expectation.fulfill()
            })
            
            waitForExpectations(timeout: 5.0, handler: nil)
            XCTAssertNil(password)
            
        } catch let e {
            XCTFail("Saving generic password failed with \(e.localizedDescription).")
        }
    }
    
    func testRemoveAllGenericPasswords() {
        do {
            var password: String?
            var password2: String?
            let expectation = self.expectation(description: "Get password")
            let expectation2 = self.expectation(description: "Get password2")
            
            try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
            try secureStoreWithGenericPwd.setValue("pwd_1235", useAuthentication: false, for: "genericPassword2")
            try secureStoreWithGenericPwd.removeAllValues()
            
            secureStoreWithGenericPwd.getValueAsync(for: "genericPassword", useAuthentication: false, success: { p in
                password = p
                expectation.fulfill()
            }, failure: { _ in
                password = nil
                expectation.fulfill()
            })
            
            secureStoreWithGenericPwd.getValueAsync(for: "genericPassword2", useAuthentication: false, success: { p in
                password2 = p
                expectation2.fulfill()
            }, failure: { _ in
                password2 = nil
                expectation2.fulfill()
            })
            
            waitForExpectations(timeout: 5.0, handler: nil)
            XCTAssertNil(password)
            XCTAssertNil(password2)
            
        } catch let e {
            XCTFail("Removing generic passwords failed with \(e.localizedDescription).")
        }
    }
}
