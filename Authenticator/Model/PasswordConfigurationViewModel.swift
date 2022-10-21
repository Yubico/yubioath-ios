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

class PasswordConfigurationViewModel {
    let connection = Connection()
    
    enum PasswordResult {
        case success(String?);
        case authenticationRequired;
        case wrongPassword;
        case failure(String?);
    }
    
    func changePassword(password: String, oldPassword: String?, completion: @escaping (_ result: PasswordResult) -> Void) {
        connection.startConnection { connection in
            // start a managementSession to reset any lingering auth
            connection.managementSession { _, error in
                if let error = error {
                    completion(.failure(error.localizedDescription))
                    return
                }
                connection.oathSession { session, error in
                    guard let session = session else {
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                        completion(.failure((connection as? YKFAccessoryConnection != nil) ? error!.localizedDescription : nil))
                        return
                    }
                    // This unlock is a local extension that accepts an optional String as password
                    session.unlock(password: oldPassword) { error in
                        if let error = error {
                            if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.wrongPassword.rawValue {
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Wrong password")
                                completion(.wrongPassword)
                                return
                            }
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                            completion(.failure((connection as? YKFAccessoryConnection != nil) ? error.localizedDescription : nil))
                            return
                        }
                        session.setPassword(password) { error in
                            if let error = error {
                                if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue {
                                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Authentication required")
                                    completion(.authenticationRequired)
                                    return
                                }
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                                completion(.failure((connection as? YKFAccessoryConnection != nil) ? error.localizedDescription : nil))
                                return
                            }
                            let message: String
                            if password == "" {
                                message = "Password has been removed"
                            } else if oldPassword == nil {
                                message = "Password has been set"
                            } else {
                                message = "Password has been changed"
                            }
                            YubiKitManager.shared.stopNFCConnection(withMessage: message)
                            completion(.success((connection as? YKFAccessoryConnection != nil) ? message : nil))
                            return
                        }
                    }
                }
            }
        }
    }
    
    func removePassword(password: String?, completion: @escaping (_ result: PasswordResult) -> Void) {
        self.changePassword(password: "", oldPassword: password, completion: completion)
    }
    
    deinit {
        print("Deinit PasswordConfigurationViewModel")
    }
}


extension YKFOATHSession {
    fileprivate func unlock(password: String?, completion: @escaping (_ error: Error?) -> Void) {
        if let password = password {
            self.unlock(withPassword: password, completion: completion)
        } else {
            completion(nil)
        }
    }
}
