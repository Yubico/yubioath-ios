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
    func onTouchRequired()
    func onOperationRetry(operation: OATHOperation)
}

protocol OperationDelegate: class {
    func onTouchRequired()
    func onError(operation: OATHOperation, error: Error)
    func onCompleted(operation: OATHOperation)
    func onUpdate(credentials: Array<Credential>)
    func onUpdate(credential: Credential)
}

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
        return operationQueue.operationCount == 0 && operationQueue.pendingOperations.count == 0
    }
    
    public func calculateAll() {
        state = YubiKitManager.shared.accessorySession.isKeyConnected ? .loading : .idle
        let operation = CalculateAllOperation()
        operation.queuePriority = .low
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
        credential.removeTimerObservation()
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
        _credentials.forEach { credential in
            credential.removeTimerObservation()
        }

        _credentials.removeAll()

        state = .idle
        operationQueue.cancelAllOperations()
        delegate?.onOperationCompleted(operation: .cleanup)
    }
    
    public func applyFilter(filter: String?) {
        self.filter = filter?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        delegate?.onOperationCompleted(operation: .filter)
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

        let credential3 = Credential(account: "account@outlook.com", issuer: "Microsoft", code: "767691", requiresTouch: true)
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
        if !self.isPaused && YubiKitManager.shared.accessorySession.isKeyConnected {
            self.calculate(credential: credential)
        } else {
            credential.state = .expired
        }
    }    
}

//
// MARK: - CredentialExpirationDelegate
//
extension YubikitManagerModel: OperationDelegate {
    
    func onTouchRequired() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            guard let delegate = self.delegate else {
                return
            }
            
            // only if key is attached require touch
            if YubiKitManager.shared.accessorySession.isKeyConnected {
                delegate.onTouchRequired()
            }
        }
    }
    
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
            if (operation.operationName == .put) {
                self.delegate?.onOperationRetry(operation: operation)
            }
        }
    }
    
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
            let oldCredentials = Dictionary(uniqueKeysWithValues: self._credentials.map{ ($0.uniqueId, $0) })
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
            
            self._credentials.sort(by: { $0.uniqueId < $1.uniqueId })
            
            self.state = .loaded
            delegate.onOperationCompleted(operation: .calculateAll)
        }
    }
    
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
    
    func onRetry(operation: OATHOperation) {
        let retryOperation = operation.createRetryOperation()
        addOperation(operation: retryOperation, suspendQueue: true)
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
