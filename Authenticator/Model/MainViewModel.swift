/*
 * Copyright (C) Yubico.
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
import SwiftUI
import Combine


class MainViewModel: ObservableObject {
    
    @Published var accounts: [Account] = []
    @Published var accountsLoaded: Bool = false
    @Published var presentPasswordEntry: Bool = false
    @Published var passwordEntryMessage: String = ""
    @Published var error: Error?
        
    public var password = PassthroughSubject<String?, Never>()
    
    private var sessionTask: Task<(), Never>? = nil
    private var passwordCancellable: AnyCancellable? = nil
    
    init() {
        sessionTask = Task {
            for await session in OATHSessionHandler.shared.wiredSessions() {
                await updateAccounts(using: session)
                let error = await session.sessionDidEnd()
                await MainActor.run { [weak self] in
                    self?.accounts.removeAll()
                    self?.accountsLoaded = false
                    self?.error = error
                }
            }
        }
    }
    
    private func updateAccounts(using session: OATHSession? = nil) async {
        do {
            let useSession: OATHSession
            if let session {
                useSession = session
            } else {
                useSession = try await OATHSessionHandler.shared.anySession()
            }
            
            let credentials = try await useSession.calculateAll()
            DispatchQueue.main.async { [weak self] in
                self?.accounts = credentials.map { credential in
                    Account(credential: credential.credential, code: credential.code)
                }
                self?.accountsLoaded = !credentials.isEmpty
                useSession.endNFC(message: "Hepp")
            }
        } catch {
            print("updateAccounts error: \(error)")
            handle(error: error, retry: { print("👾 retry after auth..."); Task { await self.updateAccounts() }})
        }
    }

    func updateAccountsOverNFC() {
        print("👾 updateAccountsOverNFC")
        Task {
            do {
                print("👾 get session")
                let session = try await OATHSessionHandler.shared.nfcSession()
                print("👾 updateAccounts with: \(session)")
                await updateAccounts(using: session)
            } catch {
                await MainActor.run {
                    print("Set error: \(error)")
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Something went wrong")
                    self.error = error
                }
            }
        }
    }
    
    func handle(error: Error, retry: (() -> Void)? = nil) {
        YubiKitManager.shared.stopNFCConnection()
        
        if let oathError = error as? YKFOATHError,
           oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue || oathError.code == YKFOATHErrorCode.wrongPassword.rawValue {
            DispatchQueue.main.async {
                self.passwordEntryMessage = oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue ? "To prevent unauthorized access this YubiKey is protected with a password." : "Incorrect password. Re-enter password."
                self.presentPasswordEntry = true
                self.passwordCancellable = self.password.sink { password in
                    if let password {
                        Task {
                            print("👾 password: \(password)")
                            let session = try await OATHSessionHandler.shared.anySession()
                            print("👾 unlock with: \(session)")
                            do {
                                try await session.unlock(password: password)
                                retry?()
                            } catch {
                                self.handle(error: error, retry: retry)
                            }
                        }
                    }
                }
            }
        } else {
            self.error = error
        }
    }
}

extension YKFOATHCredential {
    var id: String {
        YKFOATHCredentialUtils.key(fromAccountName: accountName, issuer: issuer, period: period, type: type)
    }
}
