//
//  BaseOATHOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/4/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class BaseOATHOperation: Operation {
    weak var delegate: OperationQueueDelegate?
    let semaphore = DispatchSemaphore(value: 0)

    var operationName: OperationName {
        return .calculateAll
    }
    
    var uniqueId: String {
        return "\(operationName)"
    }
    
    var replacable: Bool {
        return false
    }
    
    override func main() {
        if (isCancelled) {
            return
        }
        
        guard let oathService = YubiKitManager.shared.keySession.oathService else {
            self.operationFailed(error: KeySessionError.noOathService)
            return
        }
        
        executeOperation(oathService: oathService)
        
        let result = semaphore.wait(timeout: .now() + 20.0)
        if (result == .timedOut) {
            if (isCancelled) {
                print("The \(uniqueId) request was cancelled and timed out")
                return
            }
            
            self.operationFailed(error: KeySessionError.timeout)
        }
    }
    
    func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        // placeholder to override main logic of operation
    }

    
    func operationRequiresTouch() {
        if (isCancelled) {
            return
        }

        delegate?.onTouchRequired()
    }

    func operationSucceeded() {
        if (isCancelled) {
            print("The \(operationName) request was cancelled")
            semaphore.signal()
            return
        }

        print("The \(operationName) request succeeded")
        delegate?.onCompleted(operation: self)
        semaphore.signal()
        
        // to avoid double invocation of callback
        delegate = nil
    }
    
    func operationSucceeded(credential: Credential) {
        if (isCancelled) {
            print("The \(operationName) request was cancelled")
            semaphore.signal()
            return
        }

        print("The \(operationName) request succeeded")
        delegate?.onUpdate(credential: credential)
        semaphore.signal()
         
        // to avoid double invocation of callback
        delegate = nil
    }
    
    func operationSucceeded(credentials: Array<Credential>) {
        if (isCancelled) {
            print("The \(operationName) request was cancelled")
            semaphore.signal()
            return
        }

        print("The \(operationName) request succeeded")
        delegate?.onUpdate(credentials: credentials)
        semaphore.signal()
         
        // to avoid double invocation of callback
        delegate = nil
    }
    
    func operationFailed(error: Error) {
        if (isCancelled) {
            print("The \(operationName) request cancelled")
            semaphore.signal()
            return
        }

        print("The \(operationName) request ended in error \(error.localizedDescription) ")
        delegate?.onError(operation: self, error: error)
        semaphore.signal()

        // to avoid double invocation of callback
        delegate = nil
    }
    
    func retryOperation() -> BaseOATHOperation {
        // placeholder for method that recreates new operation instance
        // with the same arguments and priority/dependencies
        // New OATH operation will be in not finished state and can be added back to OperationQueue for retry
        return self
    }
}
