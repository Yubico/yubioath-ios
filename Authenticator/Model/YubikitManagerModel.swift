//
//  YubikitManagerModel.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

protocol CredentialViewModelDelegate: class {
    func onError(operation: Operation, error: Error)
    func onOperationCompleted(operation: Operation)
    func onTouchRequired()

}

// optional delegate methods
extension CredentialViewModelDelegate {
    func onOperationCompleted(operation: Operation) {
        
    }
    func onTouchRequired() {
        
    }
}

class YubikitManagerModel : NSObject {
    weak var delegate: CredentialViewModelDelegate?
    var filter: String?
    
    private var _credentials = Array<Credential>()
    var credentials: Array<Credential> {
        get {
            if (self.filter == nil || self.filter!.isEmpty) {
                return _credentials
            }
            return _credentials.filter {
                $0.issuer.lowercased().contains(self.filter!) || $0.account.lowercased().contains(self.filter!)
            }
        }
    }
    
    public func calculateAll() {
        let operationName = Operation.calculateAll

        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(operation: operationName, error: KeySessionError.noOathService)
            return
        }

        oathService.executeCalculateAllRequest() { [weak self] (response, error) in
            guard error == nil else {
                self?.operationFailed(operation: operationName, error: error!)
                return
            }
            // If the error is nil the response cannot be empty.
            guard let response = response else {
                self?.operationFailed(operation: operationName, error: KeySessionError.noResponse)
                return
            }
            
            self?.credentials.forEach {
                $0.removeTimerObservation()
            }
            
            self?._credentials = response.credentials.map {
                let result = Credential(fromYKFOATHCredentialCalculateResult: ($0 as! YKFOATHCredentialCalculateResult))
                result.setupTimerObservation()
                result.delegate = self
                return result
            }
            self?.operationSucceeded(operation: operationName)
        }

    }
    public func calculate(credential: Credential) {
        let operationName = Operation.calculate
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(operation: operationName, error: KeySessionError.noOathService)
            return
        }

        if (credential.requiresTouch) {
            delegate?.onTouchRequired()
        }

        credential.removeTimerObservation()
        
        // TODO: set timer and invoke
        // delegate?.onTouchRequired() if operation is not completed within 2 seconds
        // to workaround HOTP credentials that don't have requiresTouch flag

        oathService.execute(YKFKeyOATHCalculateRequest(credential: credential.ykCredential)!) { [weak self] (response, error) in
            guard error == nil else {
                self?.operationFailed(operation: operationName, error: error!)
                return
            }
            guard let response = response else {
                self?.operationFailed(operation: operationName, error: KeySessionError.noResponse)
                return
            }
            credential.code = response.otp
            credential.setValidity(validity: response.validity)
            credential.setupTimerObservation()
            self?.operationSucceeded(operation: operationName)
            print("Issuer \(credential.issuer) Account \(credential.account)")

        }
    }

    public func addCredential(credential: YKFOATHCredential) {
        let operationName = Operation.put
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(operation: operationName, error: KeySessionError.noOathService)
            return
        }

//        let newCredential = Credential(fromYKFOATHCredential: credential)
//        newCredential.delegate = self
        oathService.execute(YKFKeyOATHPutRequest(credential: credential)!) {  [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(operation: operationName, error: error!)
                return
            }

            // The request was successful. The credential was added to the key.
            self?.operationSucceeded(operation: operationName)

            // calculate it TOTP
            // TODO: ask Conrad why it causes issues (multithreading?)
//            self?.calculate(credential: newCredential)
        }
    }
    
    public func deleteCredential(index: Int) {
        let operationName = Operation.delete
        let credential = self.credentials[index]
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(operation: operationName, error: KeySessionError.noOathService)
            return
        }
        oathService.execute(YKFKeyOATHDeleteRequest(credential: credential.ykCredential)!) { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(operation: operationName, error: error!)
                return
            }
            credential.removeTimerObservation()
            self?._credentials.remove(at:index)
            self?.operationSucceeded(operation: operationName)
        }
    }
    
    public func setCode(password: String) {
        let operationName = Operation.setCode
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(operation: operationName, error: KeySessionError.noOathService)
            return
        }
        oathService.execute(YKFKeyOATHSetCodeRequest(password: password)!) { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(operation: operationName, error: error!)
                return
            }
            
            self?.operationSucceeded(operation: operationName)
        }
    }
    
    public func validate(password: String) {
        let operationName = Operation.validate
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(operation: operationName, error: KeySessionError.noOathService)
            return
        }
        oathService.execute(YKFKeyOATHValidateRequest(password: password)!) { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(operation: operationName, error: error!)
                return
            }

            print("The validate request succeeded")
            
            // TODO: add something that will repeat failed request
            self?.calculateAll()
        }
    }
    
    public func reset() {
        let operationName = Operation.reset
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(operation: operationName, error: KeySessionError.noOathService)
            return
        }
        oathService.executeResetRequest { [weak self] (error) in
            guard error == nil else {
                self?.operationFailed(operation: operationName, error: error!)
                return
            }
            
            self?.operationSucceeded(operation: operationName)
        }
    }
    
    public func cleanUp() {
        credentials.forEach { credential in
            credential.removeTimerObservation()
        }

        _credentials.removeAll()
        delegate?.onOperationCompleted(operation: .cleanup)
    }
    
    public func applyFilter(filter: String?) {
        self.filter = filter?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        delegate?.onOperationCompleted(operation: .filter)
    }
    
    public func emulateSomeRecords() {
        let credentialResult = YKFOATHCredential()
        credentialResult.account = "test@yubico.com"
        credentialResult.issuer = "Yubico"
        credentialResult.type = YKFOATHCredentialType.TOTP;
        let credential = Credential(fromYKFOATHCredential: credentialResult)
        credential.code = "111222"
        credential.setValidity(validity: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(30)))
        credential.setupTimerObservation()
        self._credentials.append(credential)
        let credential2 = Credential(fromYKFOATHCredential: credentialResult)
        credential2.code = "444555"
        credential2.setValidity(validity: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(5)))
        credential2.setupTimerObservation()
        self._credentials.append(credential2)
        credentialResult.requiresTouch = true
        let credential3 = Credential(fromYKFOATHCredential: credentialResult)
        credential3.code = ""
        credential3.setValidity(validity: DateInterval(start: Date(timeIntervalSinceNow: 0), duration: TimeInterval(40)))
        credential3.setupTimerObservation()
        self._credentials.append(credential3)
        delegate?.onOperationCompleted(operation: .put)
    }
    
    func operationSucceeded(operation:Operation) {
        DispatchQueue.main.async { [weak self] in
            print("The \(operation) request succeeded")

            guard let self = self else {
                return
            }
            guard let delegate = self.delegate else {
                return
            }
            
            delegate.onOperationCompleted(operation: operation)
        }
    }
    
    func operationFailed(operation:Operation, error: Error) {
        DispatchQueue.main.async { [weak self] in
            print("The \(operation) request ended in error \(error.localizedDescription) ")

            guard let self = self else {
                return
            }
            guard let delegate = self.delegate else {
                return
            }
            
            delegate.onError(operation: operation, error: error)
        }
    }
}

//
// MARK: - CredentialExpirationDelegate
//
extension YubikitManagerModel:  CredentialExpirationDelegate {
    
    func calculateResultDidExpire(_ credential: Credential) {
        self.calculate(credential: credential)
    }
    
}

enum Operation : String {
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
