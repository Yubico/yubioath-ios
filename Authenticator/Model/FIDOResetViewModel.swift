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

class FIDOResetViewModel: ObservableObject {

    @Published var state: ResetState = .ready
    
    enum ResetState: Equatable {
        case ready, success, error(Error)
        
        static func == (lhs: FIDOResetViewModel.ResetState, rhs: FIDOResetViewModel.ResetState) -> Bool {
            switch (lhs, rhs) {
            case (.ready, .ready):
                return true
            case (.success, .success):
                return true
            case (.error(_), .error(_)):
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
                self.state = .error(FidoViewModelError.usbNotSupported)
                return
            }
            connection.fido2Session { session, error in
                guard let session = session else {
                    let errorMessage = error?.localizedDescription ?? "Unknown error"
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: errorMessage)
                    self.state = .error(errorMessage)
                    return
                }
                session.reset { error in
                    if let error = error {
                        YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                        self.state = .error(error.localizedDescription)
                    } else {
                        let message = String(localized: "FIDO accounts deleted and FIDO application reset to factory defaults.", comment: "FIDO reset confirmation message")
                        YubiKitManager.shared.stopNFCConnection(withMessage: message)
                        self.state = .success
                    }
                }
            }
        }
    }

    deinit {
        print("deinit FIDOResetViewModel")
    }
}
