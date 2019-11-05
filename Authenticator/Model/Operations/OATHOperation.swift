//
//  OATHOperation.swift
//  Authenticator
//
//  Created by Irina Makhalova on 9/4/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class OATHOperation: Operation {
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
        let keyPluggedIn = YubiKitManager.shared.accessorySession.sessionState == .open
        let oathService: YKFKeyOATHServiceProtocol
        if YubiKitDeviceCapabilities.supportsISO7816NFCTags && !keyPluggedIn {
            guard #available(iOS 13.0, *) else {
                fatalError()
            }
            guard let service = YubiKitManager.shared.nfcSession.oathService else {
                self.operationFailed(error: KeySessionError.noOathService)
                return
            }
            oathService = service
        } else {
            guard let service = YubiKitManager.shared.accessorySession.oathService else {
                self.operationFailed(error: KeySessionError.noOathService)
                return
            }
            oathService = service
        }
        
        executeOperation(oathService: oathService)
        
        let result = semaphore.wait(timeout: .now() + 15.0)
        if isCancelled {
            let message = result == .timedOut ? "The \(uniqueId) request was cancelled and timed out" : "The \(uniqueId) request was cancelled"
            
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
    
    func executeOperation(oathService: YKFKeyOATHServiceProtocol) {
        fatalError("Override in the OATH specific operation subclass.")
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
        delegate?.onCompleted(operation: self)
        semaphore.signal()
        
        // to avoid double invocation of callback
        delegate = nil
    }
    
    func operationSucceeded(credential: Credential) {
        if isCancelled {
            print("The \(uniqueId) request was cancelled")
            semaphore.signal()
            return
        }

        print("The \(uniqueId) request succeeded")
        delegate?.onUpdate(credential: credential)
        semaphore.signal()
         
        // to avoid double invocation of callback
        delegate = nil
    }
    
    func operationSucceeded(credentials: Array<Credential>) {
        if isCancelled {
            print("The \(uniqueId) request was cancelled")
            semaphore.signal()
            return
        }

        print("The \(uniqueId) request succeeded")
        delegate?.onUpdate(credentials: credentials)
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
    
    func createRetryOperation() -> OATHOperation {
        // placeholder for method that recreates new operation instance
        // with the same arguments and priority/dependencies
        // New OATH operation will be in not finished state and can be added back to OperationQueue for retry
        fatalError("Override this method that will create new operation with the same functionality, but in fresh not started state")
    }
}
