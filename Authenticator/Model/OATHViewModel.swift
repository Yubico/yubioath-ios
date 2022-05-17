//
//  YubikitManagerModel.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

protocol CredentialViewModelDelegate: AnyObject {
    func onError(error: Error)
    func onOperationCompleted(operation: OperationName)
    func onShowToastMessage(message: String)
    func onCredentialDelete(indexPath: IndexPath)
    func passwordFor(keyId: String, isPasswordEntryRetry: Bool, completion: @escaping (String?) -> Void)
    func cachedPasswordFor(keyId: String, completion: @escaping (String?) -> Void)
    func didValidatePassword(_ password: String, forKey key: String)
}


/*! This is main view model class that talks to YubiKit
 * It's recommended to use only methods of this class to talk to YubiKitManager (even if it's a singleton and can be accessed anywhere in code)
 * Every view controller that communicates with YubiKey should have this object initialized in contructor
 */
class OATHViewModel: NSObject, YKFManagerDelegate {
    
    var nfcConnection: YKFNFCConnection?
    
    private var lastNFCEndingTimestamp: Date?

    var didNFCEndRecently: Bool {
        guard let ts = lastNFCEndingTimestamp else { return false }
        return ts.addingTimeInterval(5) > Date()
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        lastNFCEndingTimestamp = Date()
        nfcConnection = nil
        session = nil
    }
    
    func didFailConnectingNFC(_ error: Error) {
        lastNFCEndingTimestamp = Date()
    }
    
    var accessoryConnection: YKFAccessoryConnection?

    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
        calculateAll()
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        session = nil
        self.cleanUp()
    }
    
    var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    
    func connection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            YubiKitManager.shared.startNFCConnection()
        }
    }
    
    var session: YKFOATHSession?

    func session(completion: @escaping (_ session: YKFOATHSession?) -> Void) {
        if let session = session {
            completion(session)
            return
        }
        connection { connection in
            connection.oathSession { session, error in
                if let error = error {
                    self.onError(error: error)
                }
                self.cachedKeyId = self.keyIdentifier
                self.session = session
                completion(session)
            }
        }
    }
    
    override init() {
        super.init()
        DelegateStack.shared.setDelegate(self)
    }
    
    deinit {
        DelegateStack.shared.removeDelegate(self)
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
        if !YubiKitDeviceCapabilities.supportsMFIAccessoryKey && !YubiKitDeviceCapabilities.supportsISO7816NFCTags {
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
    var cachedKeyId: String?
    var cachedKeyConfig: YKFManagementInterfaceConfiguration?
    var cachedKeyVersion: YKFVersion?
    
    var hasFilter: Bool {
        return self.filter != nil && !self.filter!.isEmpty
    }

    // MARK: - Public methods
    
    public func calculateAll() {
        session { session in
            guard let session = session else { return }
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
                    if credential.isSteam && !credential.requiresTouch {
                        self.calculateSteamTOTP(credential: credential, stopNFCWhenDone: false)
                    } else if credential.type == .TOTP &&
                        credential.requiresTouch &&
                        SettingsConfig.isBypassTouchEnabled &&
                        self.nfcConnection != nil {
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
            guard let session = session else { return }
            
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
            guard let session = session else { return }

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
            guard let session = session else { return }

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
            guard let session = session else { return }
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
    
    public func deleteCredential(credential: Credential) {
        session { session in
            guard let session = session else { return }
            session.delete(credential.ykCredential) { error in
                guard error == nil else {
                    self.onError(error: error!) {
                        self.deleteCredential(credential: credential)
                    }
                    return
                }
                YubiKitManager.shared.stopNFCConnection(withMessage: "Account deleted")
                self.onDelete(credential: credential)
            }
        }
    }
    
    public func renameCredential(credential: Credential, issuer: String, account: String) {
        session { session in
            guard let session = session else { return }
            
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
    
    func unlock(withPassword password: String, isCached: Bool, completion: @escaping ((Error?) -> Void)) {
        session { session in
            guard let session = session else { return }
            session.unlock(withPassword: password) { error in
                completion(error)
                if !isCached {
                    if error == nil, let key = self.keyIdentifier {
                        self.delegate?.didValidatePassword(password, forKey: key)
                    }
                }
            }
        }
    }
    
    public func stop() {
        cleanUp()
        accessoryConnection = nil
        nfcConnection = nil
        session = nil
    }
    
    public func cleanUp() {
        guard YubiKitDeviceCapabilities.supportsMFIAccessoryKey || YubiKitDeviceCapabilities.supportsISO7816NFCTags else {
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
            self.cachedKeyId = nil
            self.favorites = []
            
            self.state = .idle
            delegate.onOperationCompleted(operation: .cleanup)
        }
    }
    
    public func applyFilter(filter: String?) {
        self.filter = filter?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.delegate?.onOperationCompleted(operation: .filter)
    }
    
    public func copyToClipboard(credential: Credential) {
        // copy to clipbboard
        UIPasteboard.general.string = credential.code
        self.delegate?.onShowToastMessage(message: "Copied to clipboard")
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
    
    /*! Invoked when operation/request to YubiKey failed */
    func onError(error: Error, retry: (() -> Void)? = nil) {
        let errorCode = YKFOATHErrorCode(rawValue: UInt((error as NSError).code))
        // Try cached passwords and then ask user for password
        if errorCode == .authenticationRequired {
            delegate?.cachedPasswordFor(keyId: keyIdentifier!) { password in
                if let password = password {
                    // Got cached password from either memory or keychain
                    self.unlock(withPassword: password, isCached: true) { error in
                        if let error = error {
                            self.onError(error: error, retry: retry)
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Wrong password")
                        } else {
                            retry?()
                        }
                    }
                } else {
                    // No cached password, ask user for password
                    let keyId = self.keyIdentifier!
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                    self.delegate?.passwordFor(keyId: keyId, isPasswordEntryRetry: false) { password in
                        guard let password = password else { return }
                        self.unlock(withPassword: password, isCached: false) { error in
                            if let error = error {
                                self.onError(error: error, retry: retry)
                                YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Wrong password")
                            } else {
                                retry?()
                            }
                        }
                    }
                }
            }
        // Ask user for the correct password
        } else if errorCode == .wrongPassword {
            self.delegate?.passwordFor(keyId: self.keyIdentifier!, isPasswordEntryRetry: true) { password in
                guard let password = password else { return }
                self.unlock(withPassword: password, isCached: false) { error in
                    if let error = error {
                        self.onError(error: error, retry: retry)
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: "Wrong password")
                    } else {
                        retry?()
                    }
                }
            }
        } else if let error = error as? YKFSessionError, YKFSessionErrorCode(rawValue: UInt(error.code)) == .invalidSessionStateStatusCode {
            session = nil
            retry?()
        } else {
            // Stop everything and pass error to delegate
            cleanUp()
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
            
            self.favorites = self.favoritesStorage.readFavorites(userAccount: self.cachedKeyId)
            
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
            // If remove credential from favorites first and then from credentials list, the wrong indexPath will be returned.
            if let row = self._credentials.firstIndex(where: { $0 == credential }) {
                self._credentials.remove(at: row)
                if self.isPinned(credential: credential) {
                    self.unPin(credential: credential)
                }
                self.delegate?.onCredentialDelete(indexPath: IndexPath(row: row, section: 0))
            }
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
        return accessoryConnection != nil
    }
    
    var keyIdentifier: String? {
        if let accessoryConnection = accessoryConnection {
            return accessoryConnection.accessoryDescription?.serialNumber
        }
        if let nfcConnection = nfcConnection {
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
        self.favoritesStorage.saveFavorites(userAccount: self.cachedKeyId, favorites: self.favorites)
        calculateAll()
    }
    
    func unPin(credential: Credential) {
        self.favorites.remove(credential.uniqueId)
        self.favoritesStorage.saveFavorites(userAccount: self.cachedKeyId, favorites: self.favorites)
        calculateAll()
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
