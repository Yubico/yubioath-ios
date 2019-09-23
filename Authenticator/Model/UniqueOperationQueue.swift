//
//  UniqueOperationQueue.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class UniqueOperationQueue: OperationQueue {
    let serial = DispatchQueue(label: "serial", qos: .default)
    var pendingOperations : [String:OATHOperation] = [:]
    
    func add(operation: OATHOperation, suspendQueue: Bool = false) {        
        // operating on serial dispatcher thread with operation queue bcz access to pending operations and
        // suspend state should be syncronized
        
        serial.async { [weak self] in
            guard let self = self else {
                return
            }

            // if queue needs to be resumed than we add operation first and then resume queue
            // to allow operation queue to pick higher priority operation before resuming operation
            // if queus needs to be suspended than we suspend queue before adding retried operation
            // otherwise queue might restart operations right away
            if suspendQueue {
                self.isSuspended = suspendQueue
                // recreated operation should be added to the queue without any duplication checks
                self.enqueue(operation: operation)
            } else {
                // making sure that this operation in not in a queue already
                // otherwise user might click button multiple times and invoke the same operation
                if let pendingOperation = self.pendingOperations[operation.uniqueId] {
                    // update only set code and validation to the latest one, because user might corrected his input
                    if (operation.replicable || pendingOperation.isCancelled) {
                        pendingOperation.cancel()
                        self.enqueue(operation: operation)
                    } else {
                        print("\(operation.uniqueId) is skipped because it's already in queue")
                    }
                } else {
                    // add operations to queue only if there is no such request
                    self.enqueue(operation: operation)
                }
                // make sure that queue is not blocked if new operation request coming
                self.isSuspended = suspendQueue
            }
        }
    }
    
    private func enqueue(operation: OATHOperation) {
        let operationId = operation.uniqueId
        pendingOperations[operationId] = operation
        weak var weakOp = operation
        operation.completionBlock = {
            self.serial.async { [weak self] in
            // Make sure we are removing the right object, because
            // if the op was cancelled and it was replaced, we
            // don't want to remove the op that replaced it
                if weakOp == self?.pendingOperations[operationId] {
                    self?.pendingOperations[operationId] = nil
                }
            }
        }
        super.addOperation(operation)
    }
}
