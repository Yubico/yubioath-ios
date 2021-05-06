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

    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
        session = nil
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
        YubiKitManager.shared.delegate = self
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
        // sorting credentials: 1) favorites 2) alphabetically (issuer first, name second)
        if self.favorites.count > 0 {
            self._credentials.sort {
                if isFavorite(credential: $0) == isFavorite(credential: $1) {
                    return $0 < $1
                }
                return isFavorite(credential: $0)
            }
        } else {
            self._credentials.sort {
                $0 < $1
            }
        }
        
        if self.filter == nil || self.filter!.isEmpty {
            return self._credentials
        }
        return self._credentials.filter {
            $0.issuer?.lowercased().contains(self.filter!) == true || $0.account.lowercased().contains(self.filter!)
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
                    // Calculate TOTP credentials with time period != 30 individually
                    if credential.type == .TOTP && !credential.requiresTouch && credential.period != 30 {
                        session.calculate(credential.ykCredential, timestamp: Date().addingTimeInterval(10)) { code, error in
                            guard let code = code, let otp = code.otp else { return }
                            credential.setCode(code: otp, validity: code.validity)
                        }
                    }
                }
                
                session.dispatchAfterCurrentCommands {
                    self.onUpdate(credentials: credentials)
                    YubiKitManager.shared.stopNFCConnection(withMessage: "Credentials successfully read")
                }
            }
        }
    }
    
    public func calculate(credential: Credential) {
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
                YubiKitManager.shared.stopNFCConnection(withMessage: "Credential deleted")
                self.onDelete(credential: credential)
            }
        }
    }
    
    public func renameCredential(credential: Credential, issuer: String, account: String) {
        session { session in
            guard let session = session else { return }
            session.renameCredential(credential.ykCredential, newIssuer: issuer, newAccount: account) { error in
                guard error == nil else {
                    self.onError(error: error!) {
                        self.renameCredential(credential: credential, issuer: issuer, account: account)
                    }
                    return
                }
                self.calculateAll()
            }
        }
    }
    
    public func setCode(password: String) {
        session { session in
            guard let session = session else { return }
            session.setPassword(password) { error in
                guard error == nil else {
                    self.onError(error: error!)
                    return
                }
                YubiKitManager.shared.stopNFCConnection()
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
//            session.unlock(withPassword: password, completion: completion)
        }
    }
    
    public func getConfiguration() {
//        addOperation(operation: GetKeyConfigurationOperation())
    }
    
    public func setConfiguration(configuration: YKFManagementInterfaceConfiguration) {
//        addOperation(operation: SetKeyConfigurationOperation(configuration: configuration))
    }
    
    public func reset() {
//        addOperation(operation: ResetOperation())
    }
    
    public func getKeyVersion() {
//        addOperation(operation: GetKeyVersionOperation())
    }
    
    public func pause() {
//        self.isPaused = true
//        self.operationQueue.suspendQueue(suspendQueue: self.isPaused)
    }
    
    public func resume() {
//        self.isPaused = false
//        self.operationQueue.suspendQueue(suspendQueue: self.isPaused)
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
        self.delegate?.onShowToastMessage(message: "Copied to clipboard!")
    }
    
    public func emulateSomeRecords() {
        let credential = Credential(account: "account@gmail.com", issuer: "Google", code: "061361", keyVersion: YKFVersion(bytes: 5, minor: 1, micro: 1))
        credential.setupTimerObservation()
        self._credentials.append(credential)
        
        let credential2 = Credential(account: "account@gmail.com", issuer: "Facebook", code: "778725", keyVersion: YKFVersion(bytes: 5, minor: 1, micro: 1))
        credential2.setupTimerObservation()
        self._credentials.append(credential2)
        
        let credential4 = Credential(account: "account@gmail.com", issuer: "Github", code: "", requiresTouch: true, keyVersion: YKFVersion(bytes: 5, minor: 1, micro: 1))
        credential4.setupTimerObservation()
        self._credentials.append(credential4)
        
        let credential3 = Credential(account: "account@outlook.com", issuer: "Microsoft", code: "767691", keyVersion: YKFVersion(bytes: 5, minor: 1, micro: 1))
        credential3.setupTimerObservation()
        self._credentials.append(credential3)
        self.delegate?.onOperationCompleted(operation: .calculateAll)
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
            
            // in case of put operation
            // prompt user if he wants to retry this operation for another key
//            if operation.operationName == .put {
//                self.delegate?.onOperationRetry(operation: operation)
//            }
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
                if $0.requiresTouch || $0.type == .HOTP {
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
                if self.isFavorite(credential: credential) {
                    _ = self.removeFavorite(credential: credential)
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
            
            if credential.type == .HOTP {
                self.copyToClipboard(credential: credential)
            }
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
    
//    func onRetry(operation: BaseOperation, suspendQueue: Bool = true) {
//        let retryOperation = operation.createRetryOperation()
//        self.addOperation(operation: retryOperation, suspendQueue: suspendQueue)
//    }
    
//    func addOperation(operation: BaseOperation, suspendQueue: Bool = false) {
//        if self.isPaused {
//            return
//        }
//        operation.delegate = self
//        self.operationQueue.add(operation: operation, suspendQueue: suspendQueue)
//    }
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
    
    func startNfc() {
        YubiKitManager.shared.startNFCConnection()
//        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
//            guard #available(iOS 13.0, *) else {
//                fatalError()
//            }
//            if YubiKitManager.shared.nfcSession.iso7816SessionState != .closed {
//                YubiKitManager.shared.nfcSession.stopIso7816Session()
//            }
//            YubiKitManager.shared.nfcSession.startIso7816Session()
//        }
    }

    func stopNfc() {
        YubiKitManager.shared.stopNFCConnection()
//        if YubiKitDeviceCapabilities.supportsISO7816NFCTags && self.isQueueEmpty() && YubiKitManager.shared.nfcSession.iso7816SessionState != .closed{
//            guard #available(iOS 13.0, *) else {
//                fatalError()
//            }
//
//            YubiKitManager.shared.nfcSession.stopIso7816Session()
//        }
    }
        /*
    func nfcStateChanged(state: YKFNFCISO7816SessionState) {

        let oldState = self.nfcState
        self.nfcState = state
        guard #available(iOS 13.0, *) else {
            fatalError()
        }
        print("NFC key session state: \(String(describing: state.rawValue))")
        if state == .open {
            YubiKitManager.shared.nfcSession.setAlertMessage("Reading the data")
        } else if state == .pooling {
            if oldState == .open {
                // Closing session because YubiKey was removed from NFC reader.
                self.stopNfc()
            } else {
                YubiKitManager.shared.nfcSession.setAlertMessage("Scan your YubiKey")
            }
        } else if state == .closed {
            guard let error = YubiKitManager.shared.nfcSession.iso7816SessionError else {
                return
            }
            let errorCode = (error as NSError).code
            if errorCode == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
                // if user pressed cancel button we won't proceed with queueed operations
                self.operationQueue.cancelAllOperations()
            }
            print("NFC key session error: \(error.localizedDescription)")
        }
    }
     */
}

// MARK: - Operations with Favorites set.

extension OATHViewModel {
    
    func isFavorite(credential: Credential) -> Bool {
        return self.favorites.contains(credential.uniqueId)
    }
    
    func addFavorite(credential: Credential) -> IndexPath {
        self.favorites.insert(credential.uniqueId)
        self.favoritesStorage.saveFavorites(userAccount: self.cachedKeyId, favorites: self.favorites)
        return IndexPath(row: self.credentials.firstIndex { $0 == credential } ?? 0, section: 0)
    }
    
    func removeFavorite(credential: Credential) -> IndexPath {
        self.favorites.remove(credential.uniqueId)
        self.favoritesStorage.saveFavorites(userAccount: self.cachedKeyId, favorites: self.favorites)
        return IndexPath(row: self.credentials.firstIndex { $0 == credential } ?? 0, section: 0)
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
