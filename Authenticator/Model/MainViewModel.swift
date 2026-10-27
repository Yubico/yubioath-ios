/*
 * Copyright (C) Yubico.
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

import Foundation
import SwiftUI
import YubiKit


@Observable class MainViewModel {
    
    var accounts: [Account] = []
    var pinnedAccounts: [Account] = []
    var otherAccounts: [Account] = []
    var accountsLoaded: Bool = false
    var presentPasswordEntry: Bool = false
    var presentPasswordSaveType: Bool = false
    var presentDisableOTP: Bool = false
    var passwordEntryMessage: String = ""
    var isKeyPluggedIn: Bool = false
    var sessionError: Error?
    var connectionError: Error?
    
    var showTouchToast: Bool = false

    @ObservationIgnored var timer: Timer?

    @ObservationIgnored var accessKeyMemoryCache = AccessKeyCache()
    let accessKeySecureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    let passwordPreferences = PasswordPreferences()
    
    // Called with the password the user entered in the password alert.
    @ObservationIgnored private var passwordEntryHandler: ((String) -> Void)? = nil
    
    // Called once with the choice the user made in the save password dialog.
    @ObservationIgnored private var passwordSaveTypeHandler: ((PasswordSaveType?) -> Void)? = nil
    
    @ObservationIgnored private var refreshDebounceTask: Task<Void, Never>? = nil

    @ObservationIgnored private var sessionTask: Task<(), Never>? = nil
    
    @ObservationIgnored private var favoritesStorage = FavoritesStorage()
    @ObservationIgnored private var favorites: Set<String> = []

    @ObservationIgnored private var refreshRequestCount = 0
    
    init() {
        self.favorites = favoritesStorage.readFavorites()
    }
    
    /// Refresh requests arriving within 100 ms of each other are coalesced. A single request refreshes
    /// only that account, several requests refresh all accounts.
    private func requestRefresh(_ account: Account) {
        refreshRequestCount += 1
        refreshDebounceTask?.cancel()
        refreshDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled, let self else { return }
            let requestCount = self.refreshRequestCount
            self.refreshRequestCount = 0
            guard self.sessionTask != nil else { return }
            // Run the refresh outside the debounce task so a later request doesn't cancel it.
            if requestCount == 1 {
                Task { [weak self] in
                    await self?.updateAccount(account)
                }
            } else {
                Task { [weak self] in
                    await self?.updateAccounts()
                }
            }
        }
    }
    
    /// Called by the password alert in MainView.
    func submitPassword(_ password: String) {
        passwordEntryHandler?(password)
    }
    
    /// Called by the save password dialog in MainView. `nil` means "Not now".
    func selectPasswordSaveType(_ type: PasswordSaveType?) {
        let handler = passwordSaveTypeHandler
        passwordSaveTypeHandler = nil
        handler?(type)
    }
    
    private func stopObservingPinnedState() {
        accounts.forEach { $0.onPinnedChange = nil }
    }
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            // Scheduled on the main run loop.
            MainActor.assumeIsolated {
                for account in self?.accounts ?? [] {
                    account.updateState()
                }
            }
        }

        sessionTask = Task { [weak self] in
            do {
                for try await session in OATHSessionHandler.shared.wiredSessions() {
                    self?.isKeyPluggedIn = true
                    await self?.updateAccounts(using: session)
                    let error = await session.sessionDidEnd()
                    // stop() was called while the YubiKey was inserted and start() may have been called since.
                    guard !Task.isCancelled else { return }
                    self?.stopObservingPinnedState()
                    self?.accounts.removeAll()
                    self?.pinnedAccounts.removeAll()
                    self?.otherAccounts.removeAll()
                    self?.accountsLoaded = false
                    self?.isKeyPluggedIn = false
                    self?.sessionError = error
                }
            } catch {
                if let sessionError = error as? OATHSessionError {
                    if sessionError == .otpEnabledError {
                        self?.isKeyPluggedIn = true
                        self?.presentDisableOTP = true
                    } else if sessionError == .oathDisabledError {
                        // Don't set connectionError to avoid restart loop - use sessionError instead
                        self?.sessionError = error
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

    func closeConnections() {
        ConnectionManager.shared.suspendWiredConnections()
    }

    func stop() {
        sessionTask?.cancel()
        sessionTask = nil

        timer?.invalidate()
        timer = nil

        stopObservingPinnedState()
        accounts.removeAll()
        pinnedAccounts.removeAll()
        otherAccounts.removeAll()
        accountsLoaded = false
        isKeyPluggedIn = false
        sessionError = nil
        connectionError = nil
    }
    
    private func updateAccount(_ account: Account) async {
        do {
            let session = try await OATHSessionHandler.shared.anySession()
            
            // We can't know if a HOTP requires touch. Instead we wait for 0.5 seconds for a response and if
            // the key doesn't return we assume it requires touch.
            let isWired = session.type == .wired
            let showTouchAlert = Task { [weak self] in
                try await Task.sleep(for: .milliseconds(500))
                guard isWired, let self else { return }
                self.showTouchToast = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                // Ignore cancellation here so a shown toast is always hidden again.
                try? await Task.sleep(for: .milliseconds(100))
                self.showTouchToast = false
            }
            
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
    
    private func updateAccounts(using session: OATHSession? = nil) async {
        do {
            stopObservingPinnedState()
            let useSession: OATHSession
            if let session {
                useSession = session
            } else {
                useSession = try await OATHSessionHandler.shared.anySession()
            }
            
            let credentials = try await useSession.calculateAll()
            let updatedAccounts = try await credentials.asyncMap { (credential, otp)  in
                if credential.type == .totp && (
                    (!credential.requiresTouch && credential.isSteam) ||
                    (useSession.type == .nfc && credential.requiresTouch && SettingsConfig.isBypassTouchEnabled)) {
                    let otp = try await useSession.calculate(credential: credential)
                    return self.account(credential: credential, code: otp, keyVersion: useSession.version, connectionType: useSession.type)
                } else {
                    return self.account(credential: credential, code: otp, keyVersion: useSession.version, connectionType: useSession.type)
                }
            }
            
            self.pinnedAccounts = updatedAccounts.filter { $0.isPinned }.sorted()
            self.otherAccounts = updatedAccounts.filter { !$0.isPinned }.sorted()
            self.accounts = updatedAccounts.sorted()
            
            updatedAccounts.forEach { account in
                account.onPinnedChange = { [weak self] account in
                    guard let self else { return }
                    if account.isPinned {
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
            }
            
            self.accountsLoaded = true
            let message = SettingsConfig.showNFCSwipeHint ? String(localized: "Success!\nHint: swipe down to dismiss", comment: "iOS NFC alert success with hint") : String(localized: "Successfully read", comment: "iOS NFC alert successfully read")
            useSession.endNFC(message: message)
        } catch {
            handle(error: error, retry: { Task { await self.updateAccounts() }})
        }
    }
    
    private func account(credential: OATHSession.Credential, code: OATHSession.OTP?, keyVersion: Version, connectionType: OATHSession.ConnectionType) -> Account {
        if let account = (accounts.filter { $0.credential.id == credential.id }).first {
            account.update(otp: code)
            return account
        } else {
            let account = Account(credential: credential, code: code, keyVersion: keyVersion, requestRefresh: { [weak self] in self?.requestRefresh($0) }, connectionType: connectionType, isPinned: favorites.contains(credential.id))
            return account
        }
    }

    func updateAccountsOverNFC() {
        Task {
            do {
                let session = try await OATHSessionHandler.shared.nfcSession()
                await updateAccounts(using: session)
            } catch {
                if !error.isNFCCancelledByUser {
                    ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Something went wrong"))
                    self.sessionError = error
                }
            }
        }
    }
    
    func addAccount(_ template: YubiKitOATHSession.CredentialTemplate, requiresTouch: Bool) {
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
    
    func renameAccount(_ account: Account, issuer: String, accountName: String, completion: @escaping () -> Void) {
        Task {
            do {
                let wasPinned = account.isPinned
                let session = try await OATHSessionHandler.shared.anySession()
                let credential = try await session.renameCredential(account.credential, issuer: issuer, accountName: accountName)
                if wasPinned {
                    account.isPinned = false
                }
                account.credential = credential
                account.updateTitles()
                account.isPinned = wasPinned
                await updateAccounts(using: session)
                ConnectionManager.shared.closeNFC(message: String(localized: "Account renamed", comment: "OATH NFC account renamed"))
                completion()
            } catch {
                handle(error: error, retry: { self.renameAccount(account, issuer: issuer, accountName: accountName, completion: completion) })
            }
        }
    }
    
    func deleteAccount(_ account: Account, completion: @escaping () -> Void) {
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
        ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Key is password protected", comment: "OATH NFC password protected key"))
        self.passwordEntryMessage = isRetry ? String(localized: "Incorrect password. Re-enter password.", comment: "OATH password entry retry") : String(localized: "To prevent unauthorized access this YubiKey is protected with a password.", comment: "OATH password entry enter password")
        self.presentPasswordEntry = true
        self.passwordEntryHandler = { password in
            Task {
                do {
                    let session = try await OATHSessionHandler.shared.anySession()
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
    
    func handle(error: Error, retry: (() -> Void)? = nil) {
        if error.isOATHAuthenticationRequired {
            Task {
                if let accessKey = await self.cachedAccessKey() {
                    do {
                        let session = try await OATHSessionHandler.shared.anySession()
                        try await session.unlock(withAccessKey: accessKey)
                        retry?()
                    } catch {
                        self.collectPasswordAndUnlock() { error in
                            if let error {
                                ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Something went wrong"))
                                self.handle(error: error, retry: retry)
                            } else {
                                retry?()
                            }
                        }
                    }
                } else {
                    self.collectPasswordAndUnlock() { error in
                        if let error {
                            ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Something went wrong"))
                            self.handle(error: error, retry: retry)
                        } else {
                            retry?()
                        }
                    }
                }
            }
        } else if error.isOATHWrongPassword {
            collectPasswordAndUnlock(isRetry: true) { error in
                if let error {
                    ConnectionManager.shared.closeNFC(errorMessage: String(localized: "Something went wrong"))
                    self.handle(error: error, retry: retry)
                } else {
                    retry?()
                }
            }
        } else if error.isNFCCancelledByUser {
            // The user dismissed the NFC sheet.
        } else {
            ConnectionManager.shared.closeNFC(errorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
            self.sessionError = error
        }
    }
    
    private func cachedAccessKey() async -> Data? {
        guard let session = try? await OATHSessionHandler.shared.anySession() else { return nil }
        let keyIdentifier = session.deviceId
        // Check memory cache
        if let accessKey = self.accessKeyMemoryCache.accessKey(forKey: keyIdentifier) {
            return accessKey
        }
        // Finally check key chain
        return try? await self.accessKeySecureStore.getValue(for: keyIdentifier)
    }

    func handleAccessKeyStorage(accessKey: Data, forKey keyIdentifier: String) {
        guard !self.passwordPreferences.neverSavePassword(keyIdentifier: keyIdentifier) else { return }
        Task { [weak self] in
            guard let secureStore = self?.accessKeySecureStore else { return }
            let currentAccessKey: Data? = try? await secureStore.getValue(for: keyIdentifier)
            guard let self, accessKey != currentAccessKey else { return }
            self.presentPasswordSaveType = true
            self.passwordSaveTypeHandler = { [weak self] type in
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

extension OATHSession.Credential {
    var id: String {
        OATHCredentialId.key(accountName: accountName, issuer: issuer, period: period, isTOTP: type == .totp)
    }
}


extension Sequence {
    nonisolated(nonsending) func asyncMap<T>(_ transform: nonisolated(nonsending) (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }
}
