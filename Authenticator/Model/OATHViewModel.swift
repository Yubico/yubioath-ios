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

protocol CredentialViewModelDelegate: AnyObject {
    func showAlert(title: String, message: String?)
    func onError(error: Error)
    func onOperationCompleted(operation: OperationName)
    func onShowToastMessage(message: String)
    func onCredentialDelete(credential: Credential)
    func collectPassword(isPasswordEntryRetry: Bool, completion: @escaping (String?) -> Void)
    func collectPasswordPreferences(completion: @escaping (PasswordSaveType) -> Void)
}

enum OATHViewModelModelError: Error, LocalizedError {
    case credentialAlreadyPresent(YKFOATHCredentialTemplate);
    
    public var errorDescription: String? {
        switch self {
        case .credentialAlreadyPresent(let credential):
            return "There's already an account named \(credential.issuer.isEmpty == false ? "\(credential.issuer), \(credential.accountName)" : credential.accountName) on this YubiKey."
        }
    }
    
    var shouldClearState: Bool {
        switch self {
        case .credentialAlreadyPresent(_):
            return false
        }
    }
}

/*! This is main view model class that talks to YubiKit
 * It's recommended to use only methods of this class to talk to YubiKitManager (even if it's a singleton and can be accessed anywhere in code)
 * Every view controller that communicates with YubiKey should have this object initialized in contructor
 */
class OATHViewModel: NSObject, YKFManagerDelegate {
    
    private var nfcConnection: YKFNFCConnection?
    
    private var lastNFCStartTimestamp: Date?
    private var lastNFCEndTimestamp: Date?

    var accessKeyMemoryCache = AccessKeyCache()
    let accessKeySecureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
    let passwordPreferences = PasswordPreferences()

    var didNFCEndRecently: Bool {
        guard let ts = lastNFCEndTimestamp else { return false }
        return ts.addingTimeInterval(5) > Date()
    }
    
    var didNFCStartRecently: Bool {
        guard let ts = lastNFCStartTimestamp else { return false }
        return ts.addingTimeInterval(2) > Date()
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        lastNFCStartTimestamp = Date()
        if let callback = connectionCallback {
            callback(connection)
        }
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        lastNFCEndTimestamp = Date()
        nfcConnection = nil
        session = nil
    }
    
    func didFailConnectingNFC(_ error: Error) {
        lastNFCEndTimestamp = Date()
    }
    
    private var accessoryConnection: YKFAccessoryConnection?

    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        wiredConnectionStatusCallbacks.forEach { callback in
            callback(.connected)
        }
        accessoryConnection = connection
        calculateAll()
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        wiredConnectionStatusCallbacks.forEach { callback in
            callback(.disconnected)
        }
        accessoryConnection = nil
        session = nil
        self.cleanUp()
    }
    
    private var smartCardConnection: YKFSmartCardConnection?

    func didConnectSmartCard(_ connection: YKFSmartCardConnection) {
        wiredConnectionStatusCallbacks.forEach { callback in
            callback(.connected)
        }
        smartCardConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
        calculateAll()
    }
    
    func didDisconnectSmartCard(_ connection: YKFSmartCardConnection, error: Error?) {
        wiredConnectionStatusCallbacks.forEach { callback in
            callback(.disconnected)
        }
        smartCardConnection = nil
        session = nil
        self.cleanUp()
    }
    
    private var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    
    private func connection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else if let connection = smartCardConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
                YubiKitManager.shared.startNFCConnection()
            }
        }
    }
    
    private var session: YKFOATHSession?

    private func session(completion: @escaping (_ session: YKFOATHSession) -> Void) {
        if let session = session {
            completion(session)
            return
        }
        connection { connection in
            connection.oathSession { session, error in
                if let error {
                    self.onError(error: error)
                } else if let session {
                    self.cachedKeyIdentifier = session.deviceId
                    self.session = session
                    completion(session)
                } else {
                    fatalError("YubiKit returned neither a session nor an error.")
                }
            }
        }
    }
    
    override init() {
        super.init()
        self.favoritesStorage.migrate()
        DelegateStack.shared.setDelegate(self)
    }
    
    deinit {
        DelegateStack.shared.removeDelegate(self)
    }
    
    enum WiredConnectionStatus {
        case connected
        case disconnected
    }
    
    typealias WiredConnectionStatusCallback = (WiredConnectionStatus) -> ()
    
    private var wiredConnectionStatusCallbacks = [WiredConnectionStatusCallback]()
    
    func wiredConnectionStatus(callback: @escaping WiredConnectionStatusCallback) {
        wiredConnectionStatusCallbacks.append(callback)
    }
    
    /*!
     * The OperationDelegate callbacks and the completion block handlers for OATH operation will be dispatched on this queue.
     */
    weak var delegate: CredentialViewModelDelegate?
    var filter: String?
    
    /*!
     * Allows to pause calculation of expired credentials in background
     */
    /*!
     * Allows to detect whether credentials list empty because device doesn't have any credentials or it's not loaded from device yet
     */
    var state: State = {
        if !YubiKitDeviceCapabilities.supportsMFIAccessoryKey
            && !YubiKitDeviceCapabilities.supportsISO7816NFCTags
            && !YubiKitDeviceCapabilities.supportsSmartCardOverUSBC {
            return .notSupported
        } else {
            return .idle
        }
    }()
    
    private var _credentials = [Credential]()
    
    /*! Property that should give you a list of credentials with applied filter (if user is searching) */
    var credentials: [Credential] {
        return credentials(pinned: false)
    }
    
    var pinnedCredentials: [Credential] {
        return credentials(pinned: true)
    }
    
    private func credentials(pinned: Bool) -> [Credential] {
        let credentials = _credentials.filter {
            pinned == isPinned(credential: $0)
        }.sorted()
        
        if let filter = filter, !filter.isEmpty {
            return credentials.filter {
                $0.issuer?.lowercased().contains(filter) == true || $0.account.lowercased().contains(filter)
            }
        } else {
            return credentials
        }
    }

    private var favoritesStorage = FavoritesStorage()
    private var favorites: Set<String> = []
    
    // cashedId is used as a key to store a set of Favorites in UserDefaults.
    var cachedKeyIdentifier: String?
    var cachedKeyConfig: YKFManagementInterfaceConfiguration?
    var cachedKeyVersion: YKFVersion?
    
    var hasFilter: Bool {
        return self.filter != nil && !self.filter!.isEmpty
    }

    // MARK: - Public methods
    
    public func calculateAll() {
        session { session in
            session.calculateAll(withTimestamp: Date().addingTimeInterval(10)) { result, error in
                guard let result = result else {
                    self.onError(error: error!, retry: {
                        self.calculateAll()
                    })
                    return
                }
                let credentials = result.map { credential in
                    return Credential(credential: credential, keyVersion: session.version)
                }
                
                credentials.forEach { credential in
                    let bypassTouch = (self.nfcConnection != nil && SettingsConfig.isBypassTouchEnabled)
                    if credential.isSteam && (!credential.requiresTouch || bypassTouch) {
                        self.calculateSteamTOTP(credential: credential, stopNFCWhenDone: false)
                    } else if credential.type == .TOTP &&
                        credential.requiresTouch &&
                        bypassTouch {
                        session.calculate(credential.ykCredential, timestamp: Date().addingTimeInterval(10)) { code, error in
                            guard let code = code, let otp = code.otp else { return }
                            credential.setCode(code: otp, validity: code.validity)
                            credential.state = .active
                        }
                    } else if credential.type == .TOTP &&
                                !credential.requiresTouch && credential.period != 30 {
                        // Calculate TOTP credentials with time period != 30 individually
                        session.calculate(credential.ykCredential, timestamp: Date().addingTimeInterval(10)) { code, error in
                            guard let code = code, let otp = code.otp else { return }
                            credential.setCode(code: otp, validity: code.validity)
                        }
                    }
                }
                
                session.dispatchAfterCurrentCommands {
                    self.onUpdate(credentials: credentials)
                    let message = SettingsConfig.showNFCSwipeHint ? "Success!\nSwipe down to dismiss" : "Successfully read"
                    YubiKitManager.shared.stopNFCConnection(withMessage: message)
                }
            }
        }
    }
    
    public func calculate(credential: Credential, completion: ((String) -> Void)? = nil) {
        if credential.isSteam {
            calculateSteamTOTP(credential: credential, stopNFCWhenDone: true, completion: completion)
        } else if credential.type == .TOTP {
            calculateTOTP(credential: credential, completion: completion)
        } else {
            calculateHOTP(credential: credential, completion: completion)
        }
    }
    
    public func calculateTOTP(credential: Credential, completion: ((String) -> Void)? = nil) {
        session { session in
            if credential.requiresTouch {
                self.onTouchRequired()
            }
            // Adding 10 extra seconds to current timestamp as boost and improvement for quick code expiration:
            // If < 10 seconds remain on the validity of a code at time of generation,
            // increment the timeslot for the challenge and increase the validity time by the period of the credential.
            // For example, if 7 seconds remain at time of generation, on a 30 second credential,
            // generate a code for the next timeslot and show a timer for 37 seconds.
            // Even if the user is very quick to enter and submit the code to the server,
            // it is very likely that it will be accepted as servers typically allow for some clock drift.
            session.calculate(credential.ykCredential, timestamp: Date().addingTimeInterval(10)) { code, error in
                guard error == nil else {
                    self.onError(error: error!) {
                        self.calculate(credential: credential)
                    }
                    return
                }
                YubiKitManager.shared.stopNFCConnection(withMessage: "Code calculated")
                guard let code = code, let otp = code.otp else {
                    if let error = error {
                        self.onError(error: error)
                    }
                    return
                }
                credential.setCode(code: otp, validity: code.validity)
                credential.state = .active
                if let completion = completion {
                    completion(otp)
                }
                self.onUpdate(credential: credential)
            }
        }
    }
    
    public func calculateHOTP(credential: Credential, completion: ((String) -> Void)? = nil) {
        session { session in
            // We can't know if a HOTP requires touch. Instead we wait for 0.5 seconds for a response and if
            // the key doesn't return we assume it requires touch.
            let showTouchAlert = DispatchWorkItem { self.onTouchRequired() }
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: showTouchAlert)
            
            session.calculate(credential.ykCredential) { code, error in
                showTouchAlert.cancel()
                guard error == nil else {
                    self.onError(error: error!) {
                        self.calculate(credential: credential)
                    }
                    return
                }
                YubiKitManager.shared.stopNFCConnection(withMessage: "Code calculated")
                guard let code = code, let otp = code.otp else {
                    if let error = error {
                        self.onError(error: error)
                    }
                    return
                }
                credential.setCode(code: otp, validity: code.validity)
                credential.state = .active
                if let completion = completion {
                    completion(otp)
                }
                self.onUpdate(credential: credential)
            }
        }
    }
    
    public func calculateSteamTOTP(credential: Credential, stopNFCWhenDone: Bool, completion: ((String) -> Void)? = nil) {
        session { session in
            if credential.requiresTouch {
                self.onTouchRequired()
            }
            
            session.calculateSteamTOTP(credential: credential) { code, validity, error in
                guard let code = code, let validity = validity else {
                    self.onError(error: error!) {
                        self.calculate(credential: credential)
                    }
                    return
                }
                if stopNFCWhenDone {
                    YubiKitManager.shared.stopNFCConnection(withMessage: "Code calculated")
                }
                credential.setCode(code: code, validity: validity)
                credential.state = .active
                if let completion = completion {
                    completion(code)
                }
                self.onUpdate(credential: credential)
            }
        }
    }
    
    public func addCredential(credential: YKFOATHCredentialTemplate, requiresTouch: Bool) {
        session { session in
            session.listCredentials { credentials, error in
                guard let credentials else {
                    self.onError(error: error!) {
                        self.addCredential(credential: credential, requiresTouch: requiresTouch)
                    }
                    return
                }
                
                let key = YKFOATHCredentialUtils.key(fromAccountName: credential.accountName, issuer: credential.issuer, period: credential.period, type: credential.type)
                
                let keys = credentials.map { YKFOATHCredentialUtils.key(fromAccountName: $0.accountName, issuer: $0.issuer, period: $0.period, type: $0.type) }
                
                guard !keys.contains(key) else {
                    self.onError(error: OATHViewModelModelError.credentialAlreadyPresent(credential))
                    return
                }
                
                session.put(credential, requiresTouch: requiresTouch) { error in
                    guard error == nil else {
                        self.onError(error: error!) {
                            self.addCredential(credential: credential, requiresTouch: requiresTouch)
                        }
                        return
                    }
                    self.calculateAll()
                }
            }
        }
    }
    
    public func deleteCredential(credential: Credential) {
        session { session in
            session.delete(credential.ykCredential) { error in
                guard error == nil else {
                    self.onError(error: error!) {
                        self.deleteCredential(credential: credential)
                    }
                    return
                }
                self.calculateAll()
                self.onDelete(credential: credential)
            }
        }
    }
    
    public func renameCredential(credential: Credential, issuer: String, account: String) {
        session { session in
            let wasPinned = self.isPinned(credential: credential)
            
            session.renameCredential(credential.ykCredential, newIssuer: issuer, newAccount: account) { error in
                guard error == nil else {
                    self.onError(error: error!) {
                        self.renameCredential(credential: credential, issuer: issuer, account: account)
                    }
                    return
                }
                
                if wasPinned {
                    self.unPin(credential: credential)
                }
                
                credential.issuer = issuer
                credential.account = account
                YubiKitManager.shared.stopNFCConnection(withMessage: "Account renamed")
                
                if wasPinned {
                    self.pin(credential: credential)
                }
                
                self.onUpdate(credential: credential)
            }
        }
    }
    
    func cachedAccessKey(completion: @escaping (Data?) -> Void) {
        session { session in
            let keyIdentifier = session.deviceId
            // access key memory cach
            if let accessKey = self.accessKeyMemoryCache.accessKey(forKey: keyIdentifier) {
                completion(accessKey)
                return
            }
            
            // persistent legacy password cache
            if let legacyKeyIdentifier = self.legacyKeyIdentifier {
                self.accessKeySecureStore.getValue(for: legacyKeyIdentifier) { legacyResult in
                    switch legacyResult {
                    case .success(let password):
                        self.passwordPreferences.migrate(fromKeyIdentifier: legacyKeyIdentifier, toKeyIdentifier: keyIdentifier)
                        let accesskey = session.deriveAccessKey(password)
                        try? self.accessKeySecureStore.removeValue(for: legacyKeyIdentifier) // remove legacy password
                        try? self.accessKeySecureStore.setValue(accesskey, useAuthentication: self.passwordPreferences.useScreenLock(keyIdentifier: keyIdentifier), for: keyIdentifier) // store access key instead
                        completion(accesskey)
                    case .failure(_):
                        // persistent access key cache
                        self.accessKeySecureStore.getValue(for: keyIdentifier) { result in
                            let accessKey = try? result.get()
                            completion(accessKey)
                            return
                        }
                    }
                }
            } else {
                self.accessKeySecureStore.getValue(for: keyIdentifier) { result in
                    let accessKey = try? result.get()
                    completion(accessKey)
                    return
                }
            }
        }
    }
    
    public func stop() {
        cleanUp()
        accessoryConnection = nil
        smartCardConnection = nil
        nfcConnection = nil
        session = nil
    }
    
    public func cleanUp() {
        guard YubiKitDeviceCapabilities.supportsMFIAccessoryKey
                || YubiKitDeviceCapabilities.supportsSmartCardOverUSBC
                || YubiKitDeviceCapabilities.supportsISO7816NFCTags else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            guard let delegate = self.delegate else {
                return
            }
            
            self._credentials.forEach { credential in
                credential.removeTimerObservation()
            }
            
            self._credentials.removeAll()
            self.cachedKeyIdentifier = nil
            self.favorites = []
            
            self.state = .idle
            delegate.onOperationCompleted(operation: .cleanup)
        }
    }
    
    public func applyFilter(filter: String?) {
        self.filter = filter?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.delegate?.onOperationCompleted(operation: .filter)
    }
    
    public func copyToClipboard(value: String, message: String = "Copied to clipboard") {
        // copy to clipbboard
        UIPasteboard.general.string = value
        self.delegate?.onShowToastMessage(message: message)
    }
    
    public func emulateSomeRecords() {
        let credential1 = Credential(account: "account@gmail.com", issuer: "YubiKey 5.4.2", code: "063313", keyVersion: YKFVersion(string: "5.4.2"))
        let credential2 = Credential(account: "john.b.doe@gmail.com", issuer: "YubiKey 5.2.6", code: "87254433", keyVersion: YKFVersion(string: "5.2.6"))
        let credential3 = Credential(account: "account@gmail.com", issuer: "Github", code: "", requiresTouch: true, keyVersion: YKFVersion(string: "5.4.2"))
        let credential4 = Credential(account: "account@yubico.com", issuer: "Yubico", code: "767691", keyVersion: YKFVersion(bytes: 5, minor: 1, micro: 1))
        let credential5 = Credential(account: "short-period@yubico.com", issuer: "15 sec period", period: 15, code: "740921", keyVersion: YKFVersion(string: "5.4.2"))
        let credential6 = Credential(account: "jane.elaine.doe@dropbox.com", issuer: "Dropbox with a much loonger name", code: "555555", keyVersion: YKFVersion(string: "5.4.2"))
        let credential7 = Credential(type: .HOTP, account: "hotp@yubico.com", issuer: "HOTP", code: "343344", keyVersion: YKFVersion(string: "5.4.2"))
        let credential8 = Credential(account: "account@tesla.com", issuer: "Tesla", code: "420420", keyVersion: YKFVersion(string: "5.4.2"))
        let credential9 = Credential(account: "jane.elaine.doe@yubico.com", issuer: "", code: "420420", keyVersion: YKFVersion(string: "5.4.2"))
        credentials.forEach { credential in
            credential.setupTimerObservation()
        }
        let credentials = [credential1, credential2, credential3, credential4, credential5, credential6, credential7, credential8, credential9]
        self.onUpdate(credentials: credentials)
    }
}

//

// MARK: - CredentialExpirationDelegate

//
extension OATHViewModel: CredentialExpirationDelegate {
    func calculateResultDidExpire(_ credential: Credential) {
        // recalculate automatically only if key is plugged in and view model is not paused (the view is in background, behind another view controller)
        if keyPluggedIn {
            self.calculate(credential: credential)
        } else {
            // if we can't recalculate credential set state to expired
            credential.state = .expired
        }
    }
}

//

// MARK: - CredentialExpirationDelegate

//
extension OATHViewModel { //}: OperationDelegate {
    /*! Invoked in case we started executing operation, but it requires touch and we need to notify user about it */
    func onTouchRequired() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            guard let delegate = self.delegate else {
                return
            }
            
            // only if key is attached require touch (otherwise user can't touch and tap YubiKey)
            // YubiKey will calculate credential over NFC connection even credential requires touch
            if self.keyPluggedIn {
                delegate.onShowToastMessage(message: "Touch your YubiKey")
            }
        }
    }
    
    func unlock(withPassword password: String, completion: (() -> Void)? = nil) {
        session { session in
            let accessKey = session.deriveAccessKey(password)
            self.unlock(withAccessKey: accessKey, cachedKey: false, completion: completion)
        }
    }
    
    func unlock(withAccessKey accessKey: Data, cachedKey: Bool = true, completion: (() -> Void)? = nil) {
        session { session in
            session.unlock(withAccessKey: accessKey, completion: { error in
                if let error {
                    self.onError(error: error, retry: completion)
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Wrong password")
                } else {
                    self.accessKeyMemoryCache.setAccessKey(accessKey, forKey: session.deviceId)
                    if !cachedKey {
                        self.handleAccessKeyStorage(accessKey: accessKey, forKey: session.deviceId)
                    }
                    completion?()
                }
            })
        }
    }
    
    func handleAccessKeyStorage(accessKey: Data, forKey keyIdentifier: String) {
        guard !self.passwordPreferences.neverSavePassword(keyIdentifier: keyIdentifier) else { return }
        self.accessKeySecureStore.getValue(for: keyIdentifier) { (result: Result<Data, Error>) -> Void in
            let currentAccessKey: Data? = try? result.get()
            if accessKey != currentAccessKey {
                self.delegate?.collectPasswordPreferences { type in
                    self.passwordPreferences.setPasswordPreference(saveType: type, keyIdentifier: keyIdentifier)
                    if self.passwordPreferences.useSavedPassword(keyIdentifier: keyIdentifier) || self.passwordPreferences.useScreenLock(keyIdentifier: keyIdentifier) {
                        do {
                            try self.accessKeySecureStore.setValue(accessKey, useAuthentication: self.passwordPreferences.useScreenLock(keyIdentifier: keyIdentifier), for: keyIdentifier)
                        } catch {
                            self.passwordPreferences.resetPasswordPreference(keyIdentifier: keyIdentifier)
                            self.delegate?.showAlert(title: "Password was not saved", message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
    
    /*! Invoked when operation/request to YubiKey failed */
    func onError(error: Error, retry: (() -> Void)? = nil) {
        // Try cached passwords and then ask user for password
        if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.authenticationRequired.rawValue {
            self.cachedAccessKey { accessKey in
                if let accessKey {
                    self.unlock(withAccessKey: accessKey, completion: retry)
                } else {
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                    self.delegate?.collectPassword(isPasswordEntryRetry: false) { password in
                        guard let password else { return }
                        self.unlock(withPassword: password, completion: retry)
                    }
                }
            }
        // Ask user for the correct password
        } else if let oathError = error as? YKFOATHError, oathError.code == YKFOATHErrorCode.wrongPassword.rawValue {
            self.delegate?.collectPassword(isPasswordEntryRetry: true) { password in
                guard let password else { return }
                self.unlock(withPassword: password, completion: retry)
            }
        } else if let sessionError = error as? YKFSessionError, sessionError.code == YKFSessionErrorCode
            .invalidSessionStateStatusCode.rawValue {
            session = nil
            retry?()
        } else {
            // Stop everything and pass error to delegate
            if let viewModelError = error as? OATHViewModelModelError {
                if viewModelError.shouldClearState {
                    session = nil
                    cleanUp()
                }
            } else {
                session = nil
                cleanUp()
            }
            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
            delegate?.onError(error: error)
        }
    }
    

    
    /*! Invoked when some operation completed but doesn't change list of credentials or its data */
    func onCompleted(operation: OperationName) {
        if operation == .validate {
            self.state = .loading
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.delegate?.onOperationCompleted(operation: operation)
        }
    }
    
    /*! Invoked when we've got new list of credentials from YubiKey */
    func onUpdate(credentials: [Credential]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            guard let delegate = self.delegate else {
                return
            }
            
            // timer observers better to set up on main thread to avoid
            // thread racing between operations
            self._credentials.forEach {
                $0.removeTimerObservation()
            }
            
            // using dictionary with uinique id as a key for quick search of existing credential object
            let oldCredentials = Dictionary(uniqueKeysWithValues: self._credentials.compactMap { $0 }.map { ($0.uniqueId, $0) })
            // not adding credentials with '_hidden' prefix to our list.
            self._credentials = credentials.filter { !$0.uniqueId.starts(with: "_hidden:") }.map {
                if $0.type == .HOTP {
                    // make update smarter and update only those that need to be updated
                    // in case HOTP and require touch keep old credential objects, because calculate all doesn't have them
                    if let oldCredential = oldCredentials[$0.uniqueId] {
                        oldCredential.setupTimerObservation()
                        return oldCredential
                    }
                }
                
                $0.setupTimerObservation()
                $0.delegate = self
                return $0
            }
            self.favorites = self.favoritesStorage.readFavorites()
            self.state = .loaded
            delegate.onOperationCompleted(operation: .calculateAll)
        }
    }
    
    func onDelete(credential: Credential) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            credential.removeTimerObservation()
            self.delegate?.onCredentialDelete(credential: credential)
        }
    }
    
    /*! Invoked when specific credential gets recalculated */
    func onUpdate(credential: Credential) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            guard let delegate = self.delegate else {
                return
            }
            
            // timer observers better to set up on main thread to avoid
            // thread racing between operations
            // making sure that credential was not removed or updated with calculate all operation
            if self._credentials.contains(credential) {
                credential.setupTimerObservation()
            }
            
            delegate.onOperationCompleted(operation: .calculate)
        }
    }
    
    func onGetConfiguration(configuration: YKFManagementInterfaceConfiguration) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.cachedKeyConfig = configuration
            
            self.delegate?.onOperationCompleted(operation: .getConfig)
        }
    }
    
    func onSetConfiguration() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            
            self.delegate?.onOperationCompleted(operation: .setConfig)
        }
    }
    
    func onGetKeyVersion(version: YKFVersion) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.cachedKeyVersion = version
            
            self.delegate?.onOperationCompleted(operation: .getKeyVersion)
        }
    }
}

// MARK: - Properties to YubikitManager sessions

extension OATHViewModel {
    /*!
     * Checks if accessory key is plugged in
     */
    var keyPluggedIn: Bool {
        return accessoryConnection != nil || smartCardConnection != nil
    }
    
    var legacyKeyIdentifier: String? {
        if let accessoryConnection {
            return accessoryConnection.accessoryDescription?.serialNumber
        }
        if let nfcConnection {
            return nfcConnection.tagDescription?.identifier.hex
        }
        return nil
    }
    
    var keyDescription: YKFAccessoryDescription? {
        return accessoryConnection?.accessoryDescription
    }
}

// MARK: - Operations with Favorites set.

extension OATHViewModel {
    
    func isPinned(credential: Credential) -> Bool {
        return self.favorites.contains(credential.uniqueId)
    }
    
    func pin(credential: Credential) {
        self.favorites.insert(credential.uniqueId)
        self.favoritesStorage.saveFavorites(self.favorites)
        delegate?.onOperationCompleted(operation: .calculateAll)
    }
    
    func unPin(credential: Credential) {
        self.favorites.remove(credential.uniqueId)
        self.favoritesStorage.saveFavorites(self.favorites)
        delegate?.onOperationCompleted(operation: .calculateAll)
    }
}

enum OperationName : String {
    case put = "put"
    case calculate = "calculate"
    case calculateAll = "calculate all"
    case delete = "delete"
    case rename = "rename"
    case setCode = "set code"
    case validate = "validate"
    case reset = "reset"
    case cleanup = "cleanup"
    case filter = "filter"
    case scan = "scan"
    case getConfig = "get configuration"
    case setConfig = "set configuration"
    case getKeyVersion = "get version"
}

enum State {
    case idle
    case loading
    case locked
    case loaded
    case notSupported
}
