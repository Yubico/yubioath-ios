/*
 * Copyright (C) Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


extension YKFConnectionProtocol {
    func oathSession(completion: @escaping (YKFOATHSession?, Bool, Error?) -> Void) {
        if self as? YKFNFCConnection != nil {
            self.managementSession { managementSession, error in
                guard let managementSession else {
                    // FIX for CRI-667: most likely the key doesn't support the management application
                    self.oathSession { session, error in
                        completion(session, false, error)
                    }
                    return
                }
                managementSession.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo else {
                        completion(nil, false, error)
                        return
                    }
                    if deviceInfo.isFIPSCapable & 0b00001000 == 0b00001000 {
                        self.securityDomainSession { session, error in
                            guard let session else {
                                completion(nil, false, error)
                                return
                            }
                            let scpKeyRef = YKFSCPKeyRef(kid: 0x13, kvn: 0x01)
                            session.getCertificateBundle(with: scpKeyRef) { certificates, error in
                                guard let last = certificates?.last else {
                                    completion(nil, false, error)
                                    return
                                }
                                let certificate = last as! SecCertificate
                                let publicKey = SecCertificateCopyKey(certificate)!
                                let scp11KeyParams = YKFSCP11KeyParams(keyRef: scpKeyRef, pkSdEcka: publicKey)
                                self.oathSession(scp11KeyParams) { session, error in
                                    completion(session, error == nil ? true : false, error)
                                    return
                                }
                            }
                        }
                    } else {
                        self.oathSession { session, error in
                            completion(session, false, error)
                        }
                    }
                }
            }
        } else {
            self.oathSession { session, error in
                completion(session, false, error)
            }
        }
    }
}
