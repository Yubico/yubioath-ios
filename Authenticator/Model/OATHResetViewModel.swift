/*
 * Copyright (C) 2022 Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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
import YubiKit

@Observable class OATHResetViewModel {

    var state: ResetState = .ready
    
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
    
    init() {
        Logger.allocation.debug("ResetOATHViewModel: init")
    }

    func reset() {
        Task {
            do {
                let connection = try await ConnectionManager.shared.anyConnection()
                let session = try await YubiKitOATHSession.makeSession(connection: connection)
                try await session.reset()
                let message = String(localized: "OATH accounts deleted and OATH application reset to factory defaults.", comment: "OATH reset confirmation message")
                ConnectionManager.shared.closeNFC(message: message)
                self.state = .success
            } catch {
                let error = LocalizedErrorWrapper(error: error)
                ConnectionManager.shared.closeNFC(errorMessage: error.localizedDescription)
                self.state = .error(error)
            }
        }
    }

    deinit {
        Logger.allocation.debug("ResetOATHViewModel: deinit")
    }
}
