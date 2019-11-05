//
//  SecureStoreTests.swift
//  AuthenticatorTests
//
//  Created by Irina Makhalova on 10/1/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

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
      try secureStoreWithGenericPwd.setValue("pwd_1234", for: "genericPassword")
    } catch (let e) {
      XCTFail("Saving generic password failed with \(e.localizedDescription).")
    }
  }
  
  func testReadGenericPassword() {
    do {
      try secureStoreWithGenericPwd.setValue("pwd_1234", for: "genericPassword")
      let password = try secureStoreWithGenericPwd.getValue(for: "genericPassword")
      XCTAssertEqual("pwd_1234", password)
    } catch (let e) {
      XCTFail("Reading generic password failed with \(e.localizedDescription).")
    }
  }
  
  func testUpdateGenericPassword() {
    do {
      try secureStoreWithGenericPwd.setValue("pwd_1234", for: "genericPassword")
      try secureStoreWithGenericPwd.setValue("pwd_updated123", for: "genericPassword")
      let password = try secureStoreWithGenericPwd.getValue(for: "genericPassword")
      XCTAssertEqual("pwd_updated123", password)
    } catch (let e) {
      XCTFail("Updating generic password failed with \(e.localizedDescription).")
    }
  }
  
  func testRemoveGenericPassword() {
    do {
      try secureStoreWithGenericPwd.setValue("pwd_1234", for: "genericPassword")
      try secureStoreWithGenericPwd.removeValue(for: "genericPassword")
      XCTAssertNil(try secureStoreWithGenericPwd.getValue(for: "genericPassword"))
    } catch (let e) {
      XCTFail("Saving generic password failed with \(e.localizedDescription).")
    }
  }
  
  
  func testRemoveAllGenericPasswords() {
    do {
      try secureStoreWithGenericPwd.setValue("pwd_1234", for: "genericPassword")
      try secureStoreWithGenericPwd.setValue("pwd_1235", for: "genericPassword2")
      try secureStoreWithGenericPwd.removeAllValues()
      XCTAssertNil(try secureStoreWithGenericPwd.getValue(for: "genericPassword"))
      XCTAssertNil(try secureStoreWithGenericPwd.getValue(for: "genericPassword2"))
    } catch (let e) {
      XCTFail("Removing generic passwords failed with \(e.localizedDescription).")
    }
  }
}
