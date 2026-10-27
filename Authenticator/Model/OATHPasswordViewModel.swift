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

import OSLog
import YubiKit

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

@Observable class OATHPasswordViewModel {
    
    var state: PasswordState = .unknown
    var isProcessing: Bool = false
    var isFipsKey: Bool = false
    
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
        Logger.allocation.debug("OATHPasswordViewModel: init")
    }

    @ObservationIgnored private var didLoad = false

    /// Reads the password state from the YubiKey. Called by the view rather than from `init` since
    /// SwiftUI may create the model several times before the view appears.
    func load() {
        guard !didLoad else { return }
        didLoad = true
        Task {
            do {
                let connection = try await ConnectionManager.shared.anyConnection()
                watchForRemoval(of: connection)
                do {
                    let deviceInfo = try await connection.managementSession().getDeviceInfo()
                    isFipsKey = deviceInfo.fipsCapabilityFlags & FIPSCapability.oath == FIPSCapability.oath
                } catch {
                    let error = LocalizedErrorWrapper(error: error)
                    ConnectionManager.shared.closeNFC(errorMessage: error.localizedDescription)
                    state = .error(error)
                    return
                }
                let session = try await connection.oathSession().session
                defer { ConnectionManager.shared.closeNFC(message: String(localized: "Password state read")) }
                do {
                    _ = try await session.listCredentials()
                    state = .notSet
                } catch where error.isOATHAuthenticationRequired {
                    state = .set
                } catch {
                    state = .error(error) // If we got this far the error is pretty exotic so bailing out like this is ok.
                }
            } catch where error.isNFCCancelledByUser {
                // The user dismissed the NFC sheet.
            } catch {
                let error = LocalizedErrorWrapper(error: error)
                ConnectionManager.shared.closeNFC(errorMessage: error.localizedDescription)
                state = .error(error)
            }
        }
    }

    deinit {
        Logger.allocation.debug("OATHPasswordViewModel: deinit")
    }

    private func watchForRemoval(of connection: SmartCardConnection) {
        Task { [weak self] in
            let error = await ConnectionManager.shared.waitUntilClosed(connection)
            if connection.isNFC && error == nil { return }
            self?.state = .keyRemoved
        }
    }

    func setPassword(_ newPassword: String, repeated repeatedPassword: String) {
        self.isProcessing = true
        self.state = .unknown
        guard newPassword == repeatedPassword else {
            self.state = .error(OATHViewModelError.passwordsDoNotMatch)
            return
        }
        Task {
            do {
                let session = try await ConnectionManager.shared.anyConnection().oathSession().session
                try await session.setPassword(newPassword)
                self.state = .didSet
                ConnectionManager.shared.closeNFC(message: String(localized: "Password has been set"))
            } catch {
                self.state = .error(error)
                ConnectionManager.shared.closeNFC(errorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
            }
            self.isProcessing = false
        }
    }

    func changePassword(old oldPassword: String, new newPassword: String?, repeated repeatedPassword: String?) {
        self.isProcessing = true
        self.state = .unknown
        guard newPassword == repeatedPassword else {
            // Wait until the next runloop to change the state so SwiftUI picks it up
            Task {
                try? await Task.sleep(for: .milliseconds(10))
                self.state = .error(OATHViewModelError.passwordsDoNotMatch)
            }
            return
        }
        Task {
            do {
                let session = try await ConnectionManager.shared.anyConnection().oathSession().session
                do {
                    try await session.unlock(password: oldPassword)
                } catch {
                    self.state = .error(error.isOATHWrongPassword ? OATHViewModelError.wrongPassword : error)
                    self.isProcessing = false
                    ConnectionManager.shared.closeNFC(errorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
                    return
                }
                if let newPassword {
                    try await session.setPassword(newPassword)
                } else {
                    try await session.deleteAccessKey()
                }
                self.state = newPassword != nil ? .didSet : .didRemove
                ConnectionManager.shared.closeNFC(message: newPassword != nil ? String(localized: "Password has been changed") : String(localized: "Password has been removed"))
            } catch {
                self.state = .error(error)
                ConnectionManager.shared.closeNFC(errorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
            }
            self.isProcessing = false
        }
    }

    func removePassword(current: String) {
        changePassword(old: current, new: nil, repeated: nil)
    }
}
