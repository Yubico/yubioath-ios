//
//  ManagementViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-04-27.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

extension String: Error {}

class ManagementViewModel {
    
    let connection = Connection()

    func deviceInfo(completion: @escaping (_ result: Result<YKFManagementDeviceInfo, Error>) -> Void) {
        connection.startConnection { connection in
            connection.managementSession { session, error in
                guard let session = session else { completion(.failure(error!)); return }
                session.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo = deviceInfo else { completion(.failure(error!)); return }
                    YubiKitManager.shared.stopNFCConnection(withMessage: "Read YubiKey device info")
                    completion(.success(deviceInfo))
                }
            }
        }
    }
}
