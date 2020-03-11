//
//  ManagmentServiceOperation.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 2/27/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

class ManagmentServiceOperation: BaseOperation {

    override func executeOperation() {
        let mgmtService: YKFKeyMGMTServiceProtocol = YKFKeyMGMTService()
        executeOperation(mgtmService: mgmtService)
    }

    func executeOperation(mgtmService: YKFKeyMGMTServiceProtocol) {
        fatalError("Override in the Managment specific operation subclass.")
    }
}
