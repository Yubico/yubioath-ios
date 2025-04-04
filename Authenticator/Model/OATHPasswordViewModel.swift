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

import OSLog

enum OATHViewModelError: Error, LocalizedError {
    
    case wrongPassword, passwordsDoNotMatch
    
    public var errorDescription: String? {
        switch self {
        case .wrongPassword:
            return String(localized: "Wrong password")
        case .passwordsDoNotMatch:
            return String(localized: "Passwords don't match")
        }
    }
}

class OATHPasswordViewModel: ObservableObject {
    
    private let connection = Connection()
    @Published var state: PasswordState = .unknown
    @Published var isProcessing: Bool = false
    @Published var isFipsKey: Bool = false
    
    enum PasswordState: Equatable {
        
        case unknown, notSet, set, error(Error), keyRemoved, didSet, didChange, didRemove
        
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
            case (.keyRemoved, .keyRemoved):
                return true
            case (.didSet, .didSet):
                return true
            case (.didChange, .didChange):
                return true
            case (.didRemove, .didRemove):
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

        func isFatalError() -> Bool {
            switch self {
            case (.error(let error)):
                if let modelError = error as? OATHViewModelError, modelError == .wrongPassword {
                    return false
                }
                if let modelError = error as? OATHViewModelError, modelError == .passwordsDoNotMatch {
                    return false
                }
                return true
            default:
                return false
            }
        }
    }
    
    init() {
        connection.startConnection { [weak self] connection in
            connection.managementSession { session, error in
                guard let session else {
                    let error: LocalizedError = error.map { LocalizedErrorWrapper(error: $0) } ?? UnknownError.error
                    DispatchQueue.main.async {
                        self?.state = .error(error)
                    }
                    return
                }
                session.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo else {
                        let error: LocalizedError = error.map { LocalizedErrorWrapper(error: $0) } ?? UnknownError.error
                        DispatchQueue.main.async {
                            self?.state = .error(error)
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self?.isFipsKey = deviceInfo.isFIPSCapable & 0b00001000 == 0b00001000
                    }
                    
                    connection.oathSession { session, _, error in
                        guard let session else {
                            let error: LocalizedError = error.map { LocalizedErrorWrapper(error: $0) } ?? UnknownError.error
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                            DispatchQueue.main.async {
                                self?.state = .error(error)
                            }
                            return
                        }
                        session.listCredentials { _, error in
                            DispatchQueue.main.async {
                                defer { YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Password state read")) }
                                guard let error = error else {
                                    self?.state = .notSet
                                    return
                                }
                                if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue {
                                    self?.state = .set
                                } else {
                                    self?.state = .error(error) // If we got this far the error is pretty exotic so bailing out like this is ok.
                                }
                            }
                        }
                    }
                }
            }
        }
        
        connection.didDisconnect { [weak self] connection, error in
            if connection as? YKFNFCConnection != nil && error == nil { return }
            DispatchQueue.main.async {
                self?.state = .keyRemoved
            }
        }
        Logger.allocation.debug("OATHPasswordViewModel: init")
    }
    
    deinit {
        Logger.allocation.debug("OATHPasswordViewModel: deinit")
    }
    
    func setPassword(_ newPassword: String, repeated repeatedPassword: String) {
        self.isProcessing = true
        self.state = .unknown
        guard newPassword == repeatedPassword else {
            self.state = .error(OATHViewModelError.passwordsDoNotMatch)
            return
        }
        connection.startConnection { connection in
            connection.oathSession { session, _, error in
                guard let session else {
                    guard let error else { return }
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.state = .error(error) // If there is no error and no session crashing is the best thing.
                    }
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
                    return
                }
                session.setPassword(newPassword) { error in
                    DispatchQueue.main.async {
                        if let error {
                            self.state = .error(error)
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
                        } else {
                            self.state = .didSet
                            YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Password has been set"))
                        }
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    func changePassword(old oldPassword: String, new newPassword: String?, repeated repeatedPassword: String?) {
        self.isProcessing = true
        self.state = .unknown
        guard newPassword == repeatedPassword else {
            // Wait until the next runloop to change the state so SwiftUI picks it up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.state = .error(OATHViewModelError.passwordsDoNotMatch)
            }
            return
        }
        connection.startConnection { connection in
            connection.oathSession { session, _, error in
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
                            if let oathError = error as? YKFOATHError, UInt(oathError.code) == YKFOATHErrorCode.wrongPassword.rawValue {
                                self.state = .error(OATHViewModelError.wrongPassword)
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
                                self.state = newPassword != nil ? .didSet : .didRemove
                                YubiKitManager.shared.stopNFCConnection(withMessage: newPassword != nil ? String(localized: "Password has been changed") : String(localized: "Password has been removed"))
                            }
                            self.isProcessing = false
                        }
                    }
                }
            }
        }
    }

    func removePassword(current: String) {
        changePassword(old: current, new: nil, repeated: nil)
    }
}
