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
    
    @Environment(\.scenePhase) var scenePhase
    
    @Published var accounts: [Account] = []
    @Published var pinnedAccounts: [Account] = []
    @Published var otherAccounts: [Account] = []
    @Published var accountsLoaded: Bool = false
    @Published var presentPasswordEntry: Bool = false
    @Published var presentPasswordSaveType: Bool = false
    @Published var presentDisableOTP: Bool = false
    @Published var passwordEntryMessage: String = ""
    @Published var isKeyPluggedIn: Bool = false
    @Published var sessionError: Error?
    @Published var connectionError: Error?
    
    @Published var showTouchToast: Bool = false

    var timer: Timer?

    var accessKeyMemoryCache = AccessKeyCache()
    let accessKeySecureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    let passwordPreferences = PasswordPreferences()
    
    public var password = PassthroughSubject<String?, Never>()
    private var passwordCancellable: AnyCancellable? = nil
    
    public var passwordSaveType = PassthroughSubject<PasswordSaveType?, Never>()
    private var passwordSaveTypeCancellable: AnyCancellable? = nil
    
    private var requestRefresh = PassthroughSubject<Account, Never>()
    private var requestRefreshCancellable: AnyCancellable? = nil

    private var sessionTask: Task<(), Never>? = nil
    
    private var favoritesStorage = FavoritesStorage()
    private var favorites: Set<String> = []
    private var favoritesCancellables = [AnyCancellable]()

    private var refreshRequestCount = 0
    
    init() {
        // Make sure to instantiate the OATHSessionHandler first to get it to be the root delegate in
        // the DelegateStack.
        _ = OATHSessionHandler.shared

        requestRefreshCancellable = requestRefresh
            .map { [weak self] account in
                self?.refreshRequestCount += 1
                return account
            }
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] account in
                guard self?.sessionTask != nil else { return }
                if self?.refreshRequestCount == 1 {
                    Task { [weak self] in
                        await self?.updateAccount(account)
                    }
                } else {
                    Task { [weak self] in
                        await self?.updateAccounts()
                    }
                }
                self?.refreshRequestCount = 0
            }
        self.favorites = favoritesStorage.readFavorites()
    }
    
    @MainActor func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            for account in self?.accounts ?? [] {
                account.updateState()
            }
        }

        sessionTask = Task { [weak self] in
            do {
                for try await session in OATHSessionHandler.shared.wiredSessions() {
                    self?.isKeyPluggedIn = true
                    await self?.updateAccounts(using: session)
                    let error = await session.sessionDidEnd()
                    await MainActor.run { [weak self] in
                        self?.favoritesCancellables.forEach { $0.cancel() }
                        self?.favoritesCancellables.removeAll()
                        self?.accounts.removeAll()
                        self?.pinnedAccounts.removeAll()
                        self?.otherAccounts.removeAll()
                        self?.accountsLoaded = false
                        self?.isKeyPluggedIn = false
                        self?.sessionError = error
                    }
                }
            } catch {
                if let sessionError = error as? OATHSessionError {
                    if sessionError == .otpEnabledError {
                        self?.presentDisableOTP = true
                    } else if sessionError != .connectionCancelled {
                        self?.connectionError = error
                    }
                } else {
                    self?.connectionError = error
                }
                self?.sessionTask?.cancel()
            }
        }
    }
    
    @MainActor func stop() {
        sessionTask?.cancel()
        sessionTask = nil

        timer?.invalidate()
        timer = nil

        accounts.removeAll()
        pinnedAccounts.removeAll()
        otherAccounts.removeAll()
        accountsLoaded = false
        isKeyPluggedIn = false
        sessionError = nil
        connectionError = nil
    }
    
    @MainActor private func updateAccount(_ account: Account) async {
        do {
            let session = try await OATHSessionHandler.shared.anySession()
            
            // We can't know if a HOTP requires touch. Instead we wait for 0.5 seconds for a response and if
            // the key doesn't return we assume it requires touch.
            let showTouchAlert = DispatchWorkItem {
                guard session.type == .wired else { return }
                self.showTouchToast = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.showTouchToast = false }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: showTouchAlert)
            
            let otp = try await session.calculate(credential: account.credential)
            
            showTouchAlert.cancel()
            
            if let account = (accounts.filter { $0.accountId == account.accountId }).first {
                account.update(otp: otp)
            }

            session.endNFC(message: String(localized: "Code calculated", comment: "OATH NFC code calculated"))
        } catch {
            handle(error: error, retry: { Task { await self.updateAccount(account) }})
        }
    }
    
    @MainActor private func updateAccounts(using session: OATHSession? = nil) async {
        do {
            favoritesCancellables.forEach { $0.cancel() }
            favoritesCancellables.removeAll()
            let useSession: OATHSession
            if let session {
                useSession = session
            } else {
                useSession = try await OATHSessionHandler.shared.anySession()
            }
            
            let credentials = try await useSession.calculateAll()
            let updatedAccounts = try await credentials.asyncMap { (credential, otp)  in
                if credential.type == .totp && (
                    (!credential.requiresTouch && (credential.period != 30 || credential.isSteam)) ||
                    (useSession.type == .nfc && credential.requiresTouch && SettingsConfig.isBypassTouchEnabled)) {
                    let otp = try await useSession.calculate(credential: credential)
                    return self.account(credential: credential, code: otp, keyVersion: useSession.version, requestRefresh: requestRefresh, connectionType: useSession.type)
                } else {
                    return self.account(credential: credential, code: otp, keyVersion: useSession.version, requestRefresh: requestRefresh, connectionType: useSession.type)
                }
            }
            
            self.pinnedAccounts = updatedAccounts.filter { $0.isPinned }.sorted()
            self.otherAccounts = updatedAccounts.filter { !$0.isPinned }.sorted()
            self.accounts = updatedAccounts.sorted()
            
            updatedAccounts.forEach { account in
                // We need to drop the first value since the Publisher sends the initial value when we start subscribing
                let cancellable = account.$isPinned.dropFirst().sink { [weak self, weak account] isPinned in
                    guard let self, let account else { return }
                    if isPinned {
                        self.favorites.insert(account.accountId)
                        self.pinnedAccounts.append(account)
                        self.pinnedAccounts = self.pinnedAccounts.sorted()
                        self.otherAccounts.removeAll { $0.accountId == account.accountId }
                    } else {
                        self.favorites.remove(account.accountId)
                        self.pinnedAccounts.removeAll { $0.accountId == account.accountId }
                        self.otherAccounts.append(account)
                        self.otherAccounts = self.otherAccounts.sorted()
                    }
                    self.favoritesStorage.saveFavorites(self.favorites)
                }
                favoritesCancellables.append(cancellable)
            }
            
            self.accountsLoaded = true
            let message = SettingsConfig.showNFCSwipeHint ? String(localized: "Success!\nHint: swipe down to dismiss", comment: "iOS NFC alert success with hint") : String(localized: "Successfully read", comment: "iOS NFC alert successfully read")
            useSession.endNFC(message: message)
        } catch {
            handle(error: error, retry: { Task { await self.updateAccounts() }})
        }
    }
    
    private func account(credential: OATHSession.Credential, code: OATHSession.OTP?, keyVersion: YKFVersion, requestRefresh: PassthroughSubject<Account, Never>, connectionType: OATHSession.ConnectionType) -> Account {
        if let account = (accounts.filter { $0.credential.id == credential.id }).first {
            account.update(otp: code)
            return account
        } else {
            let account = Account(credential: credential, code: code, keyVersion: keyVersion, requestRefresh: requestRefresh, connectionType: connectionType, isPinned: favorites.contains(credential.id))
            return account
        }
    }

    @MainActor func updateAccountsOverNFC() {
        Task {
            do {
                let session = try await OATHSessionHandler.shared.nfcSession()
                await updateAccounts(using: session)
            } catch {
                YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Something went wrong"))
                self.sessionError = error
            }
        }
    }
    
    @MainActor func addAccount(_ template: YKFOATHCredentialTemplate, requiresTouch: Bool) {
        Task {
            do {
                let session = try await OATHSessionHandler.shared.anySession()
                try await session.addCredential(template: template, requiresTouch: requiresTouch)
                await updateAccounts(using: session)
            } catch {
                handle(error: error, retry: { self.addAccount(template, requiresTouch: requiresTouch) })
            }
        }
    }
    
    @MainActor func renameAccount(_ account: Account, issuer: String, accountName: String, completion: @escaping () -> Void) {
        Task {
            do {
                let wasPinned = account.isPinned
                let session = try await OATHSessionHandler.shared.anySession()
                try await session.renameCredential(account.credential, issuer: issuer, accountName: accountName)
                if wasPinned {
                    account.isPinned = false
                }
                account.credential.issuer = issuer
                account.credential.accountName = accountName
                account.updateTitles()
                account.isPinned = wasPinned
                await updateAccounts(using: session)
                YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Account renamed", comment: "OATH NFC account renamed"))
                completion()
            } catch {
                handle(error: error, retry: { self.renameAccount(account, issuer: issuer, accountName: accountName, completion: completion) })
            }
        }
    }
    
    @MainActor func deleteAccount(_ account: Account, completion: @escaping () -> Void) {
        Task {
            do {
                let session = try await OATHSessionHandler.shared.anySession()
                try await session.deleteCredential(account.credential)
                accounts.removeAll { $0.accountId == account.accountId }
                pinnedAccounts.removeAll { $0.accountId == account.accountId }
                otherAccounts.removeAll { $0.accountId == account.accountId }
                session.endNFC(message: String(localized: "Account deleted", comment: "OATH NFC account deleted"))
                completion()
            } catch {
                handle(error: error, retry: { self.deleteAccount(account, completion: completion) })
            }
        }
    }
    
    func collectPasswordAndUnlock(isRetry: Bool = false, completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Key is password protected", comment: "OATH NFC password protected key"))
            self.passwordEntryMessage = isRetry ? String(localized: "Incorrect password. Re-enter password.", comment: "OATH password entry retry") : String(localized: "To prevent unauthorized access this YubiKey is protected with a password.", comment: "OATH password entry enter password")
            self.presentPasswordEntry = true
            self.passwordCancellable = self.password.sink { password in
                if let password {
                    Task {
                        let session = try await OATHSessionHandler.shared.anySession()
                        do {
                            let accessKey = try await session.unlock(withPassword: password)
                            self.accessKeyMemoryCache.setAccessKey(accessKey, forKey: session.deviceId)
                            self.handleAccessKeyStorage(accessKey: accessKey, forKey: session.deviceId)
                            completion(nil)
                        } catch {
                            completion(error)
                        }
                    }
                }
            }
        }
    }
    
    func handle(error: Error, retry: (() -> Void)? = nil) {
        if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue {
            self.cachedAccessKey { [self] accessKey in
                if let accessKey {
                    Task {
                        do {
                            let session = try await OATHSessionHandler.shared.anySession()
                            try await session.unlock(withAccessKey: accessKey)
                            retry?()
                        } catch {
                            self.collectPasswordAndUnlock() { error in
                                if let error {
                                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Something went wrong"))
                                    self.handle(error: error, retry: retry)
                                } else {
                                    retry?()
                                }
                            }
                        }
                    }
                } else {
                    self.collectPasswordAndUnlock() { error in
                        if let error {
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Something went wrong"))
                            self.handle(error: error, retry: retry)
                        } else {
                            retry?()
                        }
                    }
                }
            }
        } else if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.wrongPassword.rawValue {
            collectPasswordAndUnlock(isRetry: true) { error in
                if let error {
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: String(localized: "Something went wrong"))
                    self.handle(error: error, retry: retry)
                } else {
                    retry?()
                }
            }
        } else {
            YubiKitManager.shared.stopNFCConnection()
            self.sessionError = error
        }
    }
    
    private func cachedAccessKey(completion: @escaping (Data?) -> Void) {
        Task {
            do {
                let session = try await OATHSessionHandler.shared.anySession()
                let keyIdentifier = session.deviceId
                // Check memory cache
                if let accessKey = self.accessKeyMemoryCache.accessKey(forKey: keyIdentifier) {
                    completion(accessKey)
                    return
                }
                // Finally check key chain
                self.accessKeySecureStore.getValue(for: keyIdentifier) { result in
                    let accessKey = try? result.get()
                    completion(accessKey)
                }
            } catch {
                completion(nil)
            }
        }
    }
    
    func handleAccessKeyStorage(accessKey: Data, forKey keyIdentifier: String) {
        guard !self.passwordPreferences.neverSavePassword(keyIdentifier: keyIdentifier) else { return }
        self.accessKeySecureStore.getValue(for: keyIdentifier) { (result: Result<Data, Error>) -> Void in
            DispatchQueue.main.async {
                let currentAccessKey: Data? = try? result.get()
                if accessKey != currentAccessKey {
                    self.presentPasswordSaveType = true
                    self.passwordSaveTypeCancellable = self.passwordSaveType.sink { [weak self] type in
                        defer { self?.passwordSaveTypeCancellable = nil }
                        guard let type, let self else { return }
                        self.passwordPreferences.setPasswordPreference(saveType: type, keyIdentifier: keyIdentifier)
                        if type == .save || type == .lock {
                            do {
                                try self.accessKeySecureStore.setValue(accessKey, useAuthentication: self.passwordPreferences.useScreenLock(keyIdentifier: keyIdentifier), for: keyIdentifier)
                            } catch {
                                self.passwordPreferences.resetPasswordPreference(keyIdentifier: keyIdentifier)
                                self.sessionError = error
                            }
                        }
                    }
                }
            }
        }
    }
}

extension OATHSession.Credential {
    var id: String {
        YKFOATHCredentialUtils.key(fromAccountName: accountName, issuer: issuer, period: period, type: type == .totp ? .TOTP : .HOTP)
    }
}


extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
}
