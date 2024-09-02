/*
 * Copyright (C) 2022 Yubico.
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

enum FidoViewModelError: Error, LocalizedError {
    
    case usbNotSupported
    
    public var errorDescription: String? {
        switch self {
        case .usbNotSupported:
            return "Fido over USB-C is not supported by iOS. Use NFC or the desktop Yubico Authenticator instead."
        }
    }
}

class FIDOPINViewModel: ObservableObject {
    
    @Published var state: PINState = .unknown
    @Published var invalidPIN: Bool = false
    @Published var isProcessing: Bool = false
    @Published var pincomplexity: Bool = false
    @Published var minPinLength: UInt = 4
    
    enum PINState: Equatable {
        
        case unknown, notSet, set, error(Error)
        
        static func == (lhs: FIDOPINViewModel.PINState, rhs: FIDOPINViewModel.PINState) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.notSet, .notSet):
                return true
            case (.set, .set):
                return true
            case (.error(_), .error(_)):
                return true
            default:
                return false
            }
        }
        
        func isError() -> Bool {
            switch self {
            case (.error(_)):
                return true
            default:
                return false
            }
        }
    }
    
    private let connection = Connection()

    init() {
        connection.startConnection { connection in
            guard connection as? YKFSmartCardConnection == nil else {
                self.state = .error(FidoViewModelError.usbNotSupported)
                return
            }
            connection.managementSession { session, error in
                guard let session else {
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                    DispatchQueue.main.async {
                        self.state = .error(error!)
                    }
                    return
                }
                session.getDeviceInfo { deviceInfo, error in
                    guard let deviceInfo else {
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                        DispatchQueue.main.async {
                            self.state = .error(error!)
                        }
                        return
                    }
                    self.pincomplexity = deviceInfo.pinComplexity
                    connection.fido2Session { session, error in
                        guard let session else {
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                            DispatchQueue.main.async {
                                self.state = .error(error!)
                            }
                            return
                        }
                        session.getInfoWithCompletion { response, error in
                            DispatchQueue.main.async {
                                defer { YubiKitManager.shared.stopNFCConnection(withMessage: "PIN state read") }
                                guard let response else {
                                    self.state = .error(error!)
                                    return
                                }
                                self.minPinLength = response.minPinLength
                                guard let pinIsSet = response.options?["clientPin"] as? Bool else {
                                    self.state = .unknown
                                    return
                                }
                                self.state = pinIsSet ? .set : .notSet
                            }
                        }
                    }
                }
            }
        }
    }
    
    func setPIN(_ pin: String) {
        self.isProcessing = true
        connection.startConnection { connection in
            connection.fido2Session { session, error in
                guard let session else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.state = .error(error!) // If there is no error and no session crashing is the best thing.
                    }
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                    return
                }
                session.setPin(pin) { error in
                    DispatchQueue.main.async {
                        if let error {
                            self.state = .error(error)
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                        } else {
                            self.state = .set
                            YubiKitManager.shared.stopNFCConnection(withMessage: "PIN has been set")
                        }
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    func changePIN(old oldPIN: String, new newPIN: String) {
        self.invalidPIN = false
        self.isProcessing = true
        connection.startConnection { connection in
            connection.fido2Session { session, error in
                guard let session else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.state = .error(error!) // If there is no error and no session crashing is the best thing.
                    }
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                    return
                }
                session.changePin(oldPIN, to: newPIN) { error in
                    DispatchQueue.main.async {
                        if let error {
                            self.state = .error(error)
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                        } else {
                            self.state = .set
                            YubiKitManager.shared.stopNFCConnection(withMessage: "PIN has been changed")
                        }
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}
