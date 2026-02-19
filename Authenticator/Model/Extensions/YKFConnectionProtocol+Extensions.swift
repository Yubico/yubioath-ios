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

    /// Checks if the key requires SCP for a given capability over NFC and provides SCP11 key params if needed.
    /// - Parameters:
    ///   - fipsCapabilityMask: The bitmask to check against isFIPSCapable (e.g., 0b00001000 for OATH, 0b00010000 for PIV)
    ///   - completion: Returns SCP11KeyParams if SCP is required and setup succeeded, nil otherwise, or an error
    private func getSCP11KeyParamsIfNeeded(fipsCapabilityMask: UInt, completion: @escaping (YKFSCP11KeyParams?, Error?) -> Void) {
        guard self as? YKFNFCConnection != nil else {
            completion(nil, nil)
            return
        }

        self.managementSession { managementSession, error in
            guard let managementSession else {
                // CRI-667: the key most likely doesn't support the management application
                completion(nil, nil)
                return
            }
            managementSession.getDeviceInfo { deviceInfo, error in
                guard let deviceInfo else {
                    completion(nil, error)
                    return
                }
                if deviceInfo.isFIPSCapable & fipsCapabilityMask == fipsCapabilityMask {
                    self.securityDomainSession { session, error in
                        guard let session else {
                            completion(nil, error)
                            return
                        }
                        let scpKeyRef = YKFSCPKeyRef(kid: 0x13, kvn: 0x01)
                        session.getCertificateBundle(with: scpKeyRef) { certificates, error in
                            guard let last = certificates?.last else {
                                completion(nil, error)
                                return
                            }
                            let certificate = last as! SecCertificate
                            let publicKey = SecCertificateCopyKey(certificate)!
                            let scp11KeyParams = YKFSCP11KeyParams(keyRef: scpKeyRef, pkSdEcka: publicKey)
                            completion(scp11KeyParams, nil)
                        }
                    }
                } else {
                    completion(nil, nil)
                }
            }
        }
    }

    func oathSession(completion: @escaping (YKFOATHSession?, Bool, Error?) -> Void) {
        getSCP11KeyParamsIfNeeded(fipsCapabilityMask: 0b00001000) { scpKeyParams, error in
            if let error {
                completion(nil, false, error)
                return
            }
            if let scpKeyParams {
                self.oathSession(scpKeyParams) { session, error in
                    completion(session, error == nil, error)
                }
            } else {
                self.oathSession { session, error in
                    completion(session, false, error)
                }
            }
        }
    }

    func pivSession(completion: @escaping (YKFPIVSession?, Bool, Error?) -> Void) {
        getSCP11KeyParamsIfNeeded(fipsCapabilityMask: 0b00010000) { scpKeyParams, error in
            if let error {
                completion(nil, false, error)
                return
            }
            if let scpKeyParams {
                self.pivSession(scpKeyParams) { session, error in
                    completion(session, error == nil, error)
                }
            } else {
                self.pivSession { session, error in
                    completion(session, false, error)
                }
            }
        }
    }
}
