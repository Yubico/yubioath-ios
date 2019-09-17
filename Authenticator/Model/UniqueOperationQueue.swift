//
//  UniqueOperationQueue.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class UniqueOperationQueue: OperationQueue {
    var pendingOperations : [String:BaseOATHOperation] = [:]
    
    func addOperation(_ op: BaseOATHOperation) {
        // add operations to queue only if there is no such request in queue yet
        // update only set code and validation to the latest one, because user might corrected his input
        if let pendingOperation = pendingOperations[op.uniqueId] {
            if (op.replacable || pendingOperation.isCancelled) {
                pendingOperation.cancel()
                pendingOperations[op.uniqueId] = nil
                queueOperation(op)
            } else {
                print("\(op.uniqueId) is skipped because it's already in queue")
            }
        } else {
            queueOperation(op)
        }
    }
    
    func queueOperation(_ op: BaseOATHOperation) {
        pendingOperations[op.uniqueId] = op
        weak var weakOp = op
        op.completionBlock = {
            DispatchQueue.main.async { [weak self] in
            // Make sure we are removing the right object, because
            // if the op was cancelled and it was replaced, we
            // don't want to remove the op that replaced it
                if (weakOp == self?.pendingOperations[op.uniqueId]) {
                    self?.pendingOperations[op.uniqueId] = nil
                }
            }
        }
        super.addOperation(op)
    }
    
    func removeOperation(_ op: BaseOATHOperation) {
        pendingOperations[op.uniqueId] = nil
    }
}
