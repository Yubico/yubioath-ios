//
//  BaseOperation.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 3/2/20.
//  Copyright © 2020 Irina Makhalova. All rights reserved.
//

import UIKit

class BaseOperation: Operation {
    weak var delegate: OperationDelegate?
    let semaphore = DispatchSemaphore(value: 0)

    var operationName: OperationName {
        fatalError("Override the operationName")
    }
    
    var uniqueId: String {
        return "\(operationName)"
    }
    
    /*! Return true if new operation have to replace old one with the same uniqueId */
    var replicable: Bool {
        return false
    }
    
    override func main() {
        if isCancelled {
            return
        }
        
        executeOperation()
        
        let result = semaphore.wait(timeout: .now() + 15.0)
        if isCancelled {
            let message = result == .timedOut
                ? "The \(uniqueId) request was cancelled and timed out"
                : "The \(uniqueId) request was cancelled"

            print(message)
            return
        }
        
        if result == .timedOut {
            self.operationFailed(error: KeySessionError.timeout)
        }
    }
    
    override func cancel() {
        super.cancel()
        semaphore.signal()
    }

    func executeOperation() {
        fatalError("Override in the specific operation subclass.")
    }

    func operationRequiresTouch() {
        if isCancelled {
            return
        }

        delegate?.onTouchRequired()
    }

    func operationSucceeded() {
        if isCancelled {
            print("The \(uniqueId) request was cancelled")
            semaphore.signal()
            return
        }

        print("The \(uniqueId) request succeeded")
        invokeDelegateCompletion()
        semaphore.signal()
        
        // to avoid double invocation of callback
        delegate = nil
    }
        
    func operationFailed(error: Error) {
        if isCancelled {
            print("The \(uniqueId) request cancelled")
            semaphore.signal()
            return
        }

        print("The \(uniqueId) request ended in error \(error.localizedDescription) ")
        delegate?.onError(operation: self, error: error)
        semaphore.signal()

        // to avoid double invocation of callback
        delegate = nil
    }
    
    /*! Method to overide for operation that invoke another delegate method */
    func invokeDelegateCompletion() {
        delegate?.onCompleted(operation: self)
    }

    /*! Placeholder for method that recreates new operation instance
     * with the same arguments and priority/dependencies
     * New operation will be in not finished state and can be added back to OperationQueue for retry
     */
    func createRetryOperation() -> BaseOperation {
        fatalError("Override this method that will create new operation with the same functionality, but in fresh not started state")
    }
}

