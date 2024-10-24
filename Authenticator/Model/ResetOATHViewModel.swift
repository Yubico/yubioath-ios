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
import OSLog

class ResetOATHViewModel: ObservableObject {

    @Published var state: ResetState = .ready
    
    enum ResetState: Equatable {
        case ready, success, error(String)
    }
    
    private let connection = Connection()
    
    init() {
        Logger.allocation.debug("ResetOATHViewModel: init")
    }

    func reset() {
        connection.startConnection { connection in
            connection.oathSession { session, error in
                guard let session = session else {
                    let errorMessage = error?.localizedDescription ?? String(localized: "Unknown error")
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: errorMessage)
                    DispatchQueue.main.async {
                        self.state = .error(errorMessage)
                    }
                    return
                }
                session.reset { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                            self.state = .error(error.localizedDescription)
                        } else {
                            let message = String(localized: "OATH accounts deleted and OATH application reset to factory defaults.", comment: "OATH reset confirmation message")
                            YubiKitManager.shared.stopNFCConnection(withMessage: message)
                            self.state = .success
                        }
                    }
                }
            }
        }
    }

    deinit {
        Logger.allocation.debug("ResetOATHViewModel: deinit")
    }
}
