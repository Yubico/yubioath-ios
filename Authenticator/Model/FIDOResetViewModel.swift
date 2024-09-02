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

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? {
        return self
    }
}

class FIDOResetViewModel: ObservableObject {

    @Published var state: ResetState = .ready
    
    enum ResetState: Equatable {
        case ready, waitingForKeyRemove, waitingForKeyReinsert, waitingForKeyTouch, success, error(Error)
        
        static func == (lhs: FIDOResetViewModel.ResetState, rhs: FIDOResetViewModel.ResetState) -> Bool {
            switch (lhs, rhs) {
            case (.ready, .ready):
                return true
            case (.waitingForKeyRemove, .waitingForKeyRemove):
                return true
            case (.waitingForKeyReinsert, .waitingForKeyReinsert):
                return true
            case (.waitingForKeyTouch, .waitingForKeyTouch):
                return true
            case (.success, .success):
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

    func reset() {
        connection.startConnection { connection in
            guard connection as? YKFSmartCardConnection == nil else {
                DispatchQueue.main.async {
                    self.state = .error(FidoViewModelError.usbNotSupported)
                }
                return
            }
            if let connection = connection as? YKFNFCConnection {
                self.resetNFC(connection: connection)
                return
            }
            if let connection = connection as? YKFAccessoryConnection {
                self.resetAccessory(connection: connection)
                return
            }
            self.state = .error("Unknown error")
        }
    }

    deinit {
        print("deinit FIDOResetViewModel")
    }
}


extension FIDOResetViewModel {
    func resetNFC(connection: YKFNFCConnection) {
        connection.fido2Session { session, error in
            guard let session = session else {
                YubiKitManager.shared.stopNFCConnection(withErrorMessage: error!.localizedDescription)
                DispatchQueue.main.async {
                    self.state = .error(error!)
                }
                return
            }
            session.reset { error in
                DispatchQueue.main.async {
                    if let error = error {
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                        self.state = .error(error)
                    } else {
                        let message = String(localized: "FIDO accounts deleted and FIDO application reset to factory defaults.", comment: "FIDO reset confirmation message")
                        YubiKitManager.shared.stopNFCConnection(withMessage: message)
                        self.state = .success
                    }
                }
            }
        }
    }
}


extension FIDOResetViewModel {
    func resetAccessory(connection: YKFAccessoryConnection) {
        connection.fido2Session { _, error in
            if let error {
                DispatchQueue.main.async {
                    self.state = .error(error)
                }
                return
            }
            
            var cancellation = Task {
                try await Task.sleep(for: .seconds(10))
                if !Task.isCancelled {
                    DispatchQueue.main.async {
                        self.state = .error(FidoViewModelError.timeout)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.state = .waitingForKeyRemove
            }
            self.connection.didDisconnect { _, _ in
                cancellation.cancel()
                cancellation = Task {
                    try await Task.sleep(for: .seconds(10))
                    if !Task.isCancelled {
                        DispatchQueue.main.async {
                            self.state = .error(FidoViewModelError.timeout)
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.state = .waitingForKeyReinsert
                }
                self.connection.startWiredConnection { connection in
                    connection.fido2Session { session, error in
                        cancellation.cancel()
                        cancellation = Task {
                            try await Task.sleep(for: .seconds(10))
                            if !Task.isCancelled {
                                DispatchQueue.main.async {
                                    self.state = .error(FidoViewModelError.timeout)
                                }
                            }
                        }
                        DispatchQueue.main.async {
                            self.state = .waitingForKeyTouch
                        }
                        session?.reset { error in
                            DispatchQueue.main.async {
                                self.state = .success
                            }
                        }
                    }
                }
            }
        }
    }
}
