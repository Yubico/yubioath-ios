//
//  GetKeyConfigurationOperation.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/27/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

class GetKeyConfigurationOperation: ManagmentServiceOperation {
    var configuration: YKFMGMTInterfaceConfiguration?
    
    override var operationName: OperationName {
        return OperationName.getConfig
    }
    
    override init() {
        super.init()
    }

    override func executeOperation(mgtmService: YKFKeyMGMTService) {
        mgtmService.readConfiguration { [weak self] (response, error) in
            guard let self = self else {
                return
            }
            
            if let error = error {
                let errorCode = (error as NSError).code
                if errorCode == YKFKeySessionErrorCode.noConnection.rawValue {
                    self.operationFailed(error: KeySessionError.noService)
                    return
                }
                self.operationFailed(error: error)
                return
            }
            
            guard let response = response else {
                self.operationFailed(error: KeySessionError.noResponse)
                return
            }
            
            self.configuration = response.configuration
        
            self.operationSucceeded()
        }
    }
    
    override func createRetryOperation() -> ManagmentServiceOperation {
        return GetKeyConfigurationOperation()
    }
    
    override func invokeDelegateCompletion() {
        delegate?.onGetConfiguration(configuration: self.configuration!)
    }
}
