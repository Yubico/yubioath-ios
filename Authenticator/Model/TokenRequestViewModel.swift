//
//  TokenRequestViewModel.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-25.
//  Copyright © 2021 Yubico. All rights reserved.
//

@available(iOS 14.0, *)
class TokenRequestViewModel: NSObject {
    
    private var connection = Connection()
    
    override init() {
        super.init()
    }
    
    var isAccessoryKeyConnectedHandler: ((Bool) -> Void)?
    
    func isAccessoryKeyConnected(handler: @escaping (Bool) -> Void) {
        isAccessoryKeyConnectedHandler = handler
        connection.accessoryConnection { [weak self] connection in
            DispatchQueue.main.async {
                self?.isAccessoryKeyConnectedHandler?(connection != nil)
            }
        }
    }

    func handleTokenRequest(_ userInfo: [AnyHashable: Any], password: String, completion: @escaping (Error?) -> Void) {
        connection.startConnection { connection in
            connection.pivSession { session, error in
                guard let session = session else { print("No session: \(error!)"); return }
                session.verifyPin(password) { result, error in
                    guard error == nil else { print("Wrong password: \(error!)"); return }
                    guard let type = userInfo.keyType(),
                          let algorithm = userInfo.algorithm(),
                          let message = userInfo.data() else { print("No data to sign"); return }
                    session.signWithKey(in: .authentication, type: type, algorithm: algorithm, message: message) { data, error in
                        YubiKitManager.shared.stopNFCConnection()
                        guard let data = data else { completion(error!); return }
                        if let userDefaults = UserDefaults(suiteName: "group.com.yubico.Authenticator") {
                            print("Save data to userDefaults...")
                            userDefaults.setValue(data, forKey: "signedData")
                            completion(nil)
                        }
                    }
                }
            }
        }
    }
}

private extension Dictionary where Key == AnyHashable, Value: Any {
    func data() -> Data? {
        return self["data"] as? Data
    }
    
    func keyType() -> YKFPIVKeyType? {
        guard let rawValue = self["keyType"] as? UInt, let keyType = YKFPIVKeyType(rawValue: rawValue) else { return nil }
        return keyType
    }
    
    func algorithm() -> SecKeyAlgorithm? {
        guard let rawValue = self["algorithm"] as? String else { return nil }
        return SecKeyAlgorithm(rawValue: rawValue as CFString)
    }
}

extension String: Error {}

