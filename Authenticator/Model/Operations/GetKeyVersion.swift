//
//  GetKeyVersion.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/25/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import Foundation

class GetKeyVersionOperation: OATHOperation {
    private var firmwareVersion: YKFKeyVersion?
    
    override var operationName: OperationName {
        return OperationName.getKeyVersion
    }

    override func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        oathService.selectOATHApplication(completion: { [weak self] (response, error) in
            guard error == nil else {
                self?.operationFailed(error: error!)
                return
            }
            
            guard let response = response else {
                self?.operationFailed(error: KeySessionError.noResponse)
                return
            }
            
            self?.firmwareVersion = response.version
            
            DispatchQueue.main.async { [weak self] in
                self?.operationSucceeded()
            }
        })
    }
    
    override func createRetryOperation() -> OATHOperation {
        return GetKeyVersionOperation()
    }
    
    override func invokeDelegateCompletion() {
        delegate?.onGetKeyVersion(version: self.firmwareVersion!)
    }
}
