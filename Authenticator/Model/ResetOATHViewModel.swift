//
//  ResetOATHViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-08-31.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

class ResetOATHViewModel {
    let connection = Connection()
    
    enum ResetResult {
        case success(String?);
        case failure(String?);
    }
    
    func reset(completion: @escaping (_ result: ResetResult) -> Void) {
        connection.startConnection { connection in
            
            connection.oathSession { session, error in
                guard let session = session else {
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                    completion(.failure((connection as? YKFAccessoryConnection != nil) ? error!.localizedDescription : nil))
                    return
                }
                
                session.reset { error in
                    if let error = error {
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                        completion(.failure((connection as? YKFAccessoryConnection != nil) ? error.localizedDescription : nil))
                        return
                    } else {
                        let message = "OATH accounts deleted and OATH application reset to factory defaults."
                        YubiKitManager.shared.stopNFCConnection(withMessage: message)
                        completion(.success((connection as? YKFAccessoryConnection != nil) ? message: nil))
                    }
                }
            }
        }
    }

    deinit {
        print("deinit ResetOATHViewModel")
    }
}
