//
//  YubikitManagerModel.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

protocol CredentialViewModelDelegate: class {
    func onError(error: Error)
    func onOperationCompleted(operation: OperationName)
    func onShowToastMessage(message: String)
    func onOperationRetry(operation: OATHOperation)
}

protocol OperationDelegate: class {
    func onTouchRequired()
    func onError(operation: OATHOperation, error: Error)
    func onCompleted(operation: OATHOperation)
    func onUpdate(credentials: Array<Credential>)
    func onUpdate(credential: Credential)
}

/*! This is main view model class that talks to YubiKit
 * It's recommended to use only methods of this class to talk to YubiKitManager (even if it's a singleton and can be accessed anywhere in code)
 * Every view controller that communicates with YubiKey should have this object initialized in contructor
 */
class YubikitManagerModel : NSObject {
    /*!
    * The OperationDelegate callbacks and the completion block handlers for OATH operation will be dispatched on this queue.
    */
    let operationQueue: UniqueOperationQueue = UniqueOperationQueue()
    weak var delegate: CredentialViewModelDelegate?
    var filter: String?
    
    /*!
     * Allows to pause calculation of expired credentials in background
     */
    var isPaused: Bool = false
    /*!
     * Allows to detect whether credentials list empty because device doesn't have any credentials or it's not loaded from device yet
     */
    var state: State = .idle
    
    private var _credentials = Array<Credential>()
    
    /*! Property that should give you a list of credentials with applied filter (if user is searching) */
    var credentials: Array<Credential> {
        get {
            if self.filter == nil || self.filter!.isEmpty {
                return _credentials
            }
            return _credentials.filter {
                $0.issuer.lowercased().contains(self.filter!) || $0.account.lowercased().contains(self.filter!)
            }
        }
    }
    
    var hasFilter: Bool {
        get {
            return self.filter != nil && !self.filter!.isEmpty
        }
    }
        
    //
    // MARK: - Public methods
    //
    override init() {
        super.init()
        // create sequensial queue for all operations, so we don't execute multiple at once
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    public func isQueueEmpty() -> Bool {
        return (operationQueue.operationCount == 0 && operationQueue.pendingOperations.count == 0) || operationQueue.isSuspended
    }
    
    public func calculateAll() {
        state = YubiKitManager.shared.accessorySession.isKeyConnected ? .loading : .idle
        let operation = CalculateAllOperation()
        addOperation(operation: operation)
    }
    
    public func calculate(credential: Credential) {
        let operation = CalculateOperation(credential: credential)
        addOperation(operation: operation)
    }

    public func addCredential(credential: YKFOATHCredential) {
        addOperation(operation: PutOperation(credential: credential))
        addOperation(operation: CalculateAllOperation())
    }
    
    public func deleteCredential(credential: Credential) {
        addOperation(operation: DeleteOperation(credential: credential))
        addOperation(operation: CalculateAllOperation())
    }
    
    public func setCode(password: String) {
        addOperation(operation: SetCodeOperation(password: password))
    }
    
    public func validate(password: String) {
        addOperation(operation: ValidateOperation(password: password))
    }
    
    public func reset() {
        addOperation(operation: ResetOperation())
    }
        
    public func pause() {
        isPaused = true
        operationQueue.suspendQueue(suspendQueue: isPaused)
    }

    public func resume() {
        isPaused = false
        operationQueue.suspendQueue(suspendQueue: isPaused)
    }

    public func cleanUp() {
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

            self.state = .idle
            self.operationQueue.cancelAllOperations()
            delegate.onOperationCompleted(operation: .cleanup)
        }
    }
    
    public func applyFilter(filter: String?) {
        self.filter = filter?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        delegate?.onOperationCompleted(operation: .filter)
    }
    
    public func copyToClipboard(credential: Credential) {
        // copy to clipbboard
        UIPasteboard.general.string = credential.code
        delegate?.onShowToastMessage(message: "Copied to clipboard!")
    }
    
    public func emulateSomeRecords() {
        let credential = Credential(account: "account@gmail.com", issuer: "Google", code: "061361")
        credential.setupTimerObservation()
        self._credentials.append(credential)

        let credential2 = Credential(account: "account@gmail.com", issuer: "Facebook", code: "778725")
        credential2.setupTimerObservation()
        self._credentials.append(credential2)

        let credential4 = Credential(account: "account@gmail.com", issuer: "Github", code: "", requiresTouch: true)
        credential4.setupTimerObservation()
        self._credentials.append(credential4)

        let credential3 = Credential(account: "account@outlook.com", issuer: "Microsoft", code: "767691")
        credential3.setupTimerObservation()
        self._credentials.append(credential3)
        delegate?.onOperationCompleted(operation: .calculateAll)
    }    
}

//
// MARK: - CredentialExpirationDelegate
//
extension YubikitManagerModel:  CredentialExpirationDelegate {
    
    func calculateResultDidExpire(_ credential: Credential) {
        // recalculate automatically only if key is plugged in and view model is not paused (the view is in background, behind another view controller)
        if !self.isPaused && keyPluggedIn {
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
extension YubikitManagerModel: OperationDelegate {
    
    /*! Invoked in case we started executing operation, but it requires touch and we need to notify user about it*/
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
    func onError(operation: OATHOperation, error: Error) {
        switch error {
        case KeySessionError.noOathService:
            self.onRetry(operation: operation)
            state = .idle
        default:
            // do nothing
            break;
        }
        
        let errorCode = (error as NSError).code;
        // in case of authentication error supend queue but retry what was requested after resuming
        if errorCode == YKFKeyOATHErrorCode.authenticationRequired.rawValue {
            self.onRetry(operation: operation)
            state = .locked
        } else if errorCode == YKFKeyOATHErrorCode.badValidationResponse.rawValue || errorCode == YKFKeyOATHErrorCode.wrongPassword.rawValue {
            // wait for another successful validation
            operationQueue.isSuspended = true
        }
               
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.onError(error: error)
        }
    }
    
    /*! Invoked when some operation completed but doesn't change list of credentials or its data */
    func onCompleted(operation: OATHOperation) {
        if operation.operationName == .validate {
            state = .loading
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            self.delegate?.onOperationCompleted(operation: operation.operationName)

            // in case of put operation
            // prompt user if he wants to retry this operation for another key
            if operation.operationName == .put {
                self.delegate?.onOperationRetry(operation: operation)
            }
        }
    }
    
    /*! Invoked when we've got new list of credentials from YubiKey */
    func onUpdate(credentials: Array<Credential>) {
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
            let oldCredentials = Dictionary(uniqueKeysWithValues: self._credentials.compactMap{ $0 }.map{ ($0.uniqueId, $0) })
            self._credentials = credentials.map {
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
            
            for credential in self._credentials {
                // If it's TOTP credential we might need to recalculate each individually
                // if there was no correct value returned as part of calculateAll request
                // NOTE: we don't update HOTP credentials unless user specifies because
                // HOTP credentials rely on a counter which is stored on the YubiKey and the validating server.
                // Each time an OTP is generated the counter is incremented on the YubiKey,
                // but if the OTP is not sent to the server, the counters get out of sync (there is usually a small window to allow for some drift, around 5 OTPs or so).
                if credential.type == .TOTP && !credential.requiresTouch {
                    // credentials that has period other than 30 seconds needs to be recalculated
                    // calculateAll assumes that every credential has period 30 seconds
                    if credential.period != Credential.DEFAULT_PERIOD
                        // credentials that don't need to be truncated need to be reculculated as well
                        // calculateAll assumes that every credential needs to be truncated
                        || credential.isSteam {
                        self.calculate(credential: credential)
                    }
                } else if !self.keyPluggedIn && credential.type == .TOTP && credential.requiresRefresh {
                    // if we've got NFC connection touch won't be required over NFC
                    self.calculate(credential: credential)
                }
            }
            
            
            // sorting credentials: 2) shorter period first (as they expire quickly) 3) alphabetically (issuer first, name second)
            self._credentials.sort(by: { $0.uniqueId.lowercased() < $1.uniqueId.lowercased() })
            
            self.state = .loaded
            delegate.onOperationCompleted(operation: .calculateAll)
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
            
            if (credential.type == .HOTP) {
                self.copyToClipboard(credential: credential)
            }
        }
    }
    
    func onRetry(operation: OATHOperation, suspendQueue: Bool = true) {
        let retryOperation = operation.createRetryOperation()
        addOperation(operation: retryOperation, suspendQueue: suspendQueue)
    }
    
    func addOperation(operation: OATHOperation, suspendQueue: Bool = false) {
        operation.delegate = self
        operationQueue.add(operation: operation, suspendQueue: suspendQueue)
    }
}

// MARK: - Properties to YubikitManager sessions
extension YubikitManagerModel {
    /*!
     * Checks if accessory key is plugged in
     */
    var keyPluggedIn: Bool {
        get {
            return YubiKitManager.shared.accessorySession.sessionState == .open;
        }
    }
    
    var keyIdentifier: String? {
        get {
            if let accessoryDescription = YubiKitManager.shared.accessorySession.accessoryDescription {
                return accessoryDescription.serialNumber
            } else {
               if #available(iOS 13.0, *) {
                    return YubiKitManager.shared.nfcSession.tagDescription?.identifier.hex
                } else {
                    return nil
                }
            }
        }
    }
    
    var keyDescription: YKFAccessoryDescription? {
        get {
            return YubiKitManager.shared.accessorySession.accessoryDescription
        }
    }
    
    func startNfc() {
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
            guard #available(iOS 13.0, *) else {
                fatalError()
            }
            if YubiKitManager.shared.nfcSession.iso7816SessionState != .closed {
                YubiKitManager.shared.nfcSession.stopIso7816Session()
            }
            YubiKitManager.shared.nfcSession.startIso7816Session()
        }
    }

    func stopNfc() {
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags && self.isQueueEmpty() && YubiKitManager.shared.nfcSession.iso7816SessionState != .closed{
            guard #available(iOS 13.0, *) else {
                fatalError()
            }

            YubiKitManager.shared.nfcSession.stopIso7816Session()
        }
    }
    
    func nfcStateChanged(state: YKFNFCISO7816SessionState) {
        guard #available(iOS 13.0, *) else {
            fatalError()
        }
        print("NFC key session state: \(String(describing: state.rawValue))")
        if state == .open {
            YubiKitManager.shared.nfcSession.setAlertMessage("Reading the data")
        } else if (state == .pooling) {
            YubiKitManager.shared.nfcSession.setAlertMessage("Scan your YubiKey")
        } else if state == .closed {
            guard let error = YubiKitManager.shared.nfcSession.iso7816SessionError else {
                return
            }
            let errorCode = (error as NSError).code;
            if errorCode == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
                // if user pressed cancel button we won't proceed with queueed operations
                operationQueue.cancelAllOperations()
            }
            print("NFC key session error: \(error.localizedDescription)")
        }
    }
}

enum OperationName : String {
    case put = "put"
    case calculate = "calculate"
    case calculateAll = "calculate all"
    case delete = "delete"
    case setCode = "set code"
    case validate = "validate"
    case reset = "reset"
    case cleanup = "cleanup"
    case filter = "filter"
    case scan = "scan"
}

enum State {
    case idle
    case loading
    case locked
    case loaded
}
