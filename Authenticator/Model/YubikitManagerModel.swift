//
//  YubikitManagerModel.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

protocol CredentialViewModelDelegate: class {
    func onUpdated()
    func onError(error: Error)
}

class YubikitManagerModel {
    weak var delegate: CredentialViewModelDelegate?
    
    var credentials = Set<Credential>()
    var credentialsArray: Array<Credential> {
        get {
            return Array(credentials)
        }
    }
    public func calculateAll() {
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.delegate?.onError(error: KeySessionError.noOathService)
            return
        }

        oathService.executeCalculateAllRequest() { (response, error) in
            guard error == nil else {
                self.delegate?.onError(error: error!)
                print("The calculate request ended in error \(error!.localizedDescription)")
                return
            }
            // If the error is nil the response cannot be empty.
            guard let response = response else {
                self.delegate?.onError(error: KeySessionError.noResponse)
                return
            }
            
            self.credentials.forEach { credential in
                credential.removeTimerObservation()
            }
            
            self.credentials = Set<Credential>(response.credentials.map {
                let result = Credential(fromYKFOATHCredentialCalculateResult: ($0 as! YKFOATHCredentialCalculateResult))
                if (result.type == .HOTP) {
                    self.calculate(credential: result)
                } else {
                    result.setupTimerObservation()
                }
                return result
            })
            
            
            print("The calculateAll request succeeded")
            self.delegate?.onUpdated()
        }

    }
    public func calculate(credential: Credential) {
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.delegate?.onError(error: KeySessionError.noOathService)
            return
        }

        credential.removeTimerObservation()
        calculate(oathService: oathService, credential: credential.ykCredential)
    }

    public func addCredential(credential: YKFOATHCredential) {
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.delegate?.onError(error: KeySessionError.noOathService)
            return
        }
        oathService.execute(YKFKeyOATHPutRequest(credential: credential)!) { (error) in
            guard error == nil else {
                self.delegate?.onError(error: error!)
                print("The put request ended in error \(error!.localizedDescription)")
                return
            }
            // The request was successful. The credential was added to the key.
            self.calculate(oathService: oathService, credential: credential)
        }
    }
    
    public func deleteCredential(credential: Credential) {
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.delegate?.onError(error: KeySessionError.noOathService)
            return
        }
        oathService.execute(YKFKeyOATHDeleteRequest(credential: credential.ykCredential)!) { (error) in
            guard error == nil else {
                self.delegate?.onError(error: error!)
                print("The delete request ended in error \(error!.localizedDescription)")
                return
            }
            credential.removeTimerObservation()
            self.credentials.remove(credential)
            self.delegate?.onUpdated()
        }
    }
    
    public func setCode(password: String) {
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.delegate?.onError(error: KeySessionError.noOathService)
            return
        }
        oathService.execute(YKFKeyOATHSetCodeRequest(password: password)!) { (error) in
            guard error == nil else {
                self.delegate?.onError(error: error!)
                print("The set code request ended in error \(error!.localizedDescription)")
                return
            }
            
            print("The set code request succeeded")
            // TODO: add something that will notify that password set
        }
    }
    
    public func validate(password: String) {
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.delegate?.onError(error: KeySessionError.noOathService)
            return
        }
        oathService.execute(YKFKeyOATHValidateRequest(password: password)!) { (error) in
            guard error == nil else {
                self.delegate?.onError(error: error!)
                print("The validate request ended in error \(error!.localizedDescription)")
                return
            }
            print("The validate request succeeded")
            
            // TODO: add something that will repeat failed request
            self.calculateAll()
        }
    }
    
    public func cleanUp() {
        credentials.forEach { credential in
            credential.removeTimerObservation()
        }

        credentials.removeAll()
        self.delegate?.onUpdated()
    }
    
    private func calculate(oathService: YKFKeyOATHServiceProtocol, credential: YKFOATHCredential) {
        oathService.execute(YKFKeyOATHCalculateRequest(credential: credential)!) { (response, error) in
            guard error == nil else {
                self.delegate?.onError(error: error!)
                print("The calculate request ended in error \(error!.localizedDescription)")
                return
            }
            guard let response = response else {
                self.delegate?.onError(error: KeySessionError.noResponse)
                return
            }

            let calculated = Credential(fromYKFOATHCredential: credential, otp: response.otp, valid: response.validity)
            calculated.setupTimerObservation()
            self.credentials.update(with:calculated)
            self.delegate?.onUpdated()
        }
    }
}
