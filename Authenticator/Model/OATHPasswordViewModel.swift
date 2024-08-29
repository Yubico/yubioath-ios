//
//  OATHPasswordViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-22.
//  Copyright © 2024 Yubico. All rights reserved.
//

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
