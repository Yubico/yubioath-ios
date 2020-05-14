//
//  GetCachedKeyVersionOperation.swift
//  Authenticator
//
//  Created by Jens Utbult on 2020-05-14.
//  Copyright © 2020 Yubico. All rights reserved.
//

import Foundation

class GetCachedKeyVersionOperation: OATHOperation {
    private var firmwareVersion: YKFKeyVersion?
    
    override var operationName: OperationName {
        return OperationName.getCachedKeyVersion
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
            
            self?.operationSucceeded()
        })
    }
    
    override func createRetryOperation() -> OATHOperation {
        return GetKeyVersionOperation()
    }
    
    override func invokeDelegateCompletion() {
        delegate?.onGetCachedKeyVersion(version: self.firmwareVersion!)
    }
}
