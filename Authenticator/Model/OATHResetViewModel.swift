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

class OATHResetViewModel: ObservableObject {

    @Published var state: ResetState = .ready
    
    enum ResetState: Equatable {
        case ready, success, error(Error)
        
        static func == (lhs: OATHResetViewModel.ResetState, rhs: OATHResetViewModel.ResetState) -> Bool {
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
    
    init() {
        Logger.allocation.debug("ResetOATHViewModel: init")
    }

    func reset() {
        connection.startConnection { connection in
            connection.oathSession { session, error in
                guard let session = session else {
                    let error: LocalizedError = error.map { LocalizedErrorWrapper(error: $0) } ?? UnknownError.error
                    YubiKitManager.shared.stopNFCConnection(withErrorMessage: error.localizedDescription)
                    DispatchQueue.main.async {
                        self.state = .error(error)
                    }
                    return
                }
                session.reset { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            YubiKitManager.shared.stopNFCConnection(withErrorMessage: LocalizedErrorWrapper(error: error).localizedDescription)
                            self.state = .error(error)
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
