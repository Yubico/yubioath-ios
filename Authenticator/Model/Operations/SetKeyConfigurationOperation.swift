//
//  SetKeyConfigurationOperation.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/27/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

class SetKeyConfigurationOperation: ManagmentServiceOperation {
    private var configuration: YKFMGMTInterfaceConfiguration

    override var operationName: OperationName {
        return OperationName.setConfig
    }

    init(configuration: YKFMGMTInterfaceConfiguration) {
        self.configuration = configuration
        super.init()
    }

    override func executeOperation(mgtmService: YKFKeyMGMTService) {
        mgtmService.write(self.configuration, reboot: true) { [weak self] error in
            if let error = error {
                let errorCode = (error as NSError).code
                if errorCode == YKFKeySessionErrorCode.noConnection.rawValue {
                    self?.operationFailed(error: KeySessionError.noService)
                    return
                }
                self?.operationFailed(error: error)
                return
            }

            self?.operationSucceeded()
        }
    }

    override func createRetryOperation() -> ManagmentServiceOperation {
        return SetKeyConfigurationOperation(configuration: self.configuration)
    }
}
