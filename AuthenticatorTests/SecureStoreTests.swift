/*
 * Copyright (C) 2022 Yubico.
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

import Testing

@testable import Authenticator

// The tests share one keychain service, so they must not run in parallel.
@Suite(.serialized)
final class SecureStoreTests {
    let secureStoreWithGenericPwd = SecureStore(secureStoreQueryable: PasswordQueryable(service: "someService"))

    deinit {
        try? secureStoreWithGenericPwd.removeAllValues()
    }

    private func getPassword(for userAccount: String) async -> String? {
        try? await secureStoreWithGenericPwd.getValue(for: userAccount, useAuthentication: false)
    }

    @Test func saveGenericPassword() throws {
        try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
    }

    @Test func readGenericPassword() async throws {
        try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
        let password = await getPassword(for: "genericPassword")
        #expect(password == "pwd_1234")
    }

    @Test func updateGenericPassword() async throws {
        try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
        try secureStoreWithGenericPwd.setValue("pwd_updated123", useAuthentication: false, for: "genericPassword")
        let password = await getPassword(for: "genericPassword")
        #expect(password == "pwd_updated123")
    }

    @Test func removeGenericPassword() async throws {
        try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
        try secureStoreWithGenericPwd.removeValue(for: "genericPassword")
        let password = await getPassword(for: "genericPassword")
        #expect(password == nil)
    }

    @Test func removeAllGenericPasswords() async throws {
        try secureStoreWithGenericPwd.setValue("pwd_1234", useAuthentication: false, for: "genericPassword")
        try secureStoreWithGenericPwd.setValue("pwd_1235", useAuthentication: false, for: "genericPassword2")
        try secureStoreWithGenericPwd.removeAllValues()

        let password = await getPassword(for: "genericPassword")
        let password2 = await getPassword(for: "genericPassword2")
        #expect(password == nil)
        #expect(password2 == nil)
    }
}
