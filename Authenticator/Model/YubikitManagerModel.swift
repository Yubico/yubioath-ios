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
    public func calculateAll(oathService: YKFKeyOATHServiceProtocol?) {
        oathService?.executeCalculateAllRequest() { (response, error) in
            guard error == nil else {
                print("The calculate request ended in error \(error!.localizedDescription)")
                return
            }
            // If the error is nil the response cannot be empty.
            guard response != nil else {
                fatalError()
            }
            
            let credentialResponse = response!.credentials as NSArray;
            var calculatedAll = Set<Credential>()
            for credentialResponseRecord in credentialResponse {
                let calculated = Credential(fromYKFOATHCredentialCalculateResult:
                    credentialResponseRecord as! YKFOATHCredentialCalculateResult )
                calculatedAll.insert(calculated)
            }
            self.credentials = calculatedAll
            self.delegate?.onUpdated()
        }

    }
    public func calculate(oathService: YKFKeyOATHServiceProtocol?, credential: Credential) {
        calculate(oathService: oathService, credential: credential.ykCredential)
    }

    public func calculate(oathService: YKFKeyOATHServiceProtocol?, credential: YKFOATHCredential) {
        oathService?.execute(YKFKeyOATHCalculateRequest(credential: credential)!) { (response, error) in
            guard error == nil else {
                print("The calculate request ended in error \(error!.localizedDescription)")
                return
            }
            let calculated = Credential(fromYKFOATHCredential: credential, otp: response!.otp, valid: response!.validity)
            self.credentials.insert(calculated)
            self.delegate?.onUpdated()
        }
    }
    
    public func addCredential(oathService: YKFKeyOATHServiceProtocol?, credential: YKFOATHCredential) {
        oathService?.execute(YKFKeyOATHPutRequest(credential: credential)!) { (error) in
            guard error == nil else {
                print("The put request ended in error \(error!.localizedDescription)")
                return
            }
            // The request was successful. The credential was added to the key.
            self.calculate(oathService: oathService, credential: credential)
        }
    }
    
    public func deleteCredential(oathService: YKFKeyOATHServiceProtocol?, credential: Credential) {
        oathService?.execute(YKFKeyOATHDeleteRequest(credential: credential.ykCredential)!) { (error) in
            guard error == nil else {
                print("The delete request ended in error \(error!.localizedDescription)")
                return
            }
            self.delegate?.onUpdated()
        }
    }

}
