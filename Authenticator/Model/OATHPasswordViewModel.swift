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

class OATHPasswordViewModel: ObservableObject {
    
    @Published var state: PasswordState = .unknown
    @Published var invalidPassword: Bool = false
    @Published var isProcessing: Bool = false
    
    enum PasswordState: Equatable {
        
        case unknown, notSet, set, error(Error)
        
        static func == (lhs: OATHPasswordViewModel.PasswordState, rhs: OATHPasswordViewModel.PasswordState) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.notSet, .notSet):
                return true
            case (.set, .set):
                return true
            case (.error(_), .error(_)):
                return true
            default:
                return false
            }
        }
        
        func isError() -> Bool {
            switch self {
            case (.error(_)):
                return true
            default:
                return false
            }
        }
    }
    
    private let connection = Connection()

    init() {
        connection.startConnection { connection in
            connection.oathSession { session, error in
                guard let session else {
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                    DispatchQueue.main.async {
                        self.state = .error(error!)
                    }
                    return
                }
                session.listCredentials { _, error in
                    DispatchQueue.main.async {
                        defer { YubiKitManager.shared.stopNFCConnection(withMessage: "Password state read") }
                        guard let error = error else {
                            self.state = .notSet
                            return
                        }
                        if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue {
                            self.state = .set
                        } else {
                            self.state = .error(error)
                        }
                    }
                }
            }
        }
    }
    
    func setPassword(_ password: String) {
        self.isProcessing = true
        connection.startConnection { connection in
            connection.oathSession { session, error in
                guard let session else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.state = .error(error!) // If there is no error and no session crashing is the best thing.
                    }
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                    return
                }
                session.setPassword(password) { error in
                    DispatchQueue.main.async {
                        if let error {
                            self.state = .error(error)
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                        } else {
                            self.state = .set
                            YubiKitManager.shared.stopNFCConnection(withMessage: "Password has been set")
                        }
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    func changePassword(old oldPassword: String, new newPassword: String?) {
        self.invalidPassword = false
        self.isProcessing = true
        connection.startConnection { connection in
            connection.oathSession { session, error in
                guard let session else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.state = .error(error!) // If there is no error and no session crashing is the best thing.
                    }
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                    return
                }
                session.unlock(withPassword: oldPassword) { error in
                    if let error {
                        DispatchQueue.main.async {
                            if error.isInvalidPasswordError {
                                self.invalidPassword = true
                            } else {
                                self.state = .error(error)
                            }
                            self.isProcessing = false
                        }
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                        return
                    }
                    session.setPassword(newPassword ?? "") { error in
                        DispatchQueue.main.async {
                            if let error {
                                self.state = .error(error)
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                            } else {
                                self.state = newPassword != nil ? .set : .notSet
                                YubiKitManager.shared.stopNFCConnection(withMessage: newPassword != nil ? "Password has been changed" : "Password has been removed")
                            }
                            self.isProcessing = false
                        }
                    }
                }
            }
        }
    }

    func removePassword(current: String) {
        changePassword(old: current, new: nil)
    }
}

extension Error {
    var isInvalidPasswordError: Bool {
        if let oathError = self as? YKFOATHError, oathError.code == YKFOATHErrorCode.wrongPassword.rawValue {
            return true
        } else {
            return false
        }
    }
}
