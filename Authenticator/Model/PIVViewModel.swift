//
//  PIVViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-19.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation


class PIVViewModel {
    
    let connection = Connection()
    
    func didDisconnect(completion: @escaping (_ connection: YKFConnectionProtocol, _ error: Error?) -> Void) {
        connection.didDisconnect(completion: completion)
    }
    
    func listPIVCertificates(completion: @escaping (_ result: Result<SecCertificate, Error>) -> Void) {
        connection.startConnection { connection in
            connection.pivSession { session, error in
                guard let session = session else { completion(.failure(error!)); return }
                session.getCertificateIn(.signature) { certificate, error in
                    guard let certificate = certificate else { completion(.failure(error!)); return }
                    completion(.success(certificate))
                }
            }
        }
    }
}
