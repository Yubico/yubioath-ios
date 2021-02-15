/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.
///
/// https://www.raywenderlich.com/9240-keychain-services-api-tutorial-for-passwords-in-swift

import Foundation
import LocalAuthentication

/*!
 APP ID prefix required in case if we want to share storage with our other applications
 */
let APP_ID = "LQA3CS5MM7"

protocol SecureStoreQueryable {
    func setUpQuery(useAuthentication: Bool) -> [String: Any]
}

/*! Provides simple query to KeyChain specifically for password type of information
 where service is application or web site that password works with.
 Reusing the same name as our Applets on YubiKey have (e.g. OATH)
 Access group is currently not used,
 but potentially can be used if we planning to share this keychain with another application (e.g. YubiKey manager)
 */
public struct PasswordQueryable {
    let service: String
    let accessGroup: String?

    init(service: String, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }
}

extension PasswordQueryable: SecureStoreQueryable {
    func setUpQuery(useAuthentication: Bool) -> [String: Any] {
        var query: [String: Any] = [:]
        query[String(kSecClass)] = kSecClassGenericPassword
        query[String(kSecAttrService)] = service
// Access group if target environment is not simulator
#if !targetEnvironment(simulator)
        if let accessGroup = accessGroup {
            query[String(kSecAttrAccessGroup)] = "\(APP_ID)." + accessGroup
        }

        if useAuthentication {
            query[String(kSecAttrAccessControl)] = SecAccessControlCreateWithFlags(nil, // use the default allocator
                                                                                   kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                                                   .biometryCurrentSet,
                                                                                   nil) // ignore any error
            let context = LAContext()
            // Number of seconds to wait between a device unlock with biometric and another biometric authentication request.
            // So, if the user opens our app within 10 seconds of unlocking the device, we not prompting the user for FaceID/TouchID again.
            context.touchIDAuthenticationAllowableReuseDuration = 10
            query[String(kSecUseOperationPrompt)] = "Unlock YubiKey."
            query[String(kSecUseAuthenticationContext)] = context
        }
#endif
        return query
    }
}
