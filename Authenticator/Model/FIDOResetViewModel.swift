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

@Observable class FIDOResetViewModel {

    var state: ResetState = .ready
    
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
    
    @ObservationIgnored private var resetTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?

    func reset() {
        resetTask = Task {
            do {
                let connection = try await ConnectionManager.shared.anyConnection()
                switch connection {
                case is USBSmartCardConnection:
                    state = .error(FidoViewModelError.usbNotSupported)
                case let connection as NFCSmartCardConnection:
                    await resetNFC(connection: connection)
                case is LightningSmartCardConnection:
                    await resetLightning(connection: connection)
                default:
                    state = .error(String(localized: "Unknown error"))
                }
            } catch where error.isNFCCancelledByUser || error is CancellationError {
                // The user dismissed the NFC sheet or cancelled the reset.
            } catch {
                state = .error(LocalizedErrorWrapper(error: error))
            }
        }
    }

    func cancelReset() {
        resetTask?.cancel()
        timeoutTask?.cancel()
        ConnectionManager.shared.restartWiredConnection()
    }

    private func restartTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            resetTask?.cancel()
            state = .error(FidoViewModelError.timeout)
        }
    }

    init() {
        Logger.allocation.debug("FIDOresetViewModel: init")
    }
    
    deinit {
        Logger.allocation.debug("FIDOresetViewModel: deinit")
    }
}


extension FIDOResetViewModel {
    private func resetNFC(connection: NFCSmartCardConnection) async {
        do {
            let session = try await connection.fido2Session()
            try await session.reset().value
            let message = String(localized: "Reset FIDO application", comment: "FIDO reset NFC confirmation message")
            ConnectionManager.shared.closeNFC(message: message)
            state = .success
        } catch {
            let localizedError = LocalizedErrorWrapper(error: error)
            ConnectionManager.shared.closeNFC(errorMessage: localizedError.localizedDescription)
            state = .error(localizedError)
        }
    }
}


extension FIDOResetViewModel {
    /// Over Lightning the reset has to be sent within a few seconds of the YubiKey being inserted, so the user
    /// removes and reinserts it first.
    private func resetLightning(connection: SmartCardConnection) async {
        do {
            let version = try await connection.managementSession().version
            guard version < Version("5.7.0")! || version > Version("5.7.2")! else {
                state = .error(FidoViewModelError.notSupportedOverLightning)
                return
            }
            _ = try await connection.fido2Session()
        } catch {
            state = .error(error)
            return
        }

        restartTimeout()
        state = .waitingForKeyRemove

        // Subscribing keeps other screens from using the YubiKey when it's reinserted.
        var wasRemoved = ConnectionManager.shared.wiredConnection == nil
        if wasRemoved {
            state = .waitingForKeyReinsert
        }
        for await connection in ConnectionManager.shared.wiredConnections() {
            guard let connection else {
                wasRemoved = true
                restartTimeout()
                state = .waitingForKeyReinsert
                continue
            }
            guard wasRemoved else { continue }
            do {
                let session = try await connection.fido2Session()
                restartTimeout()
                state = .waitingForKeyTouch
                try await session.reset().value
                timeoutTask?.cancel()
                state = .success
            } catch {
                guard !Task.isCancelled else { return }
                timeoutTask?.cancel()
                state = .error(error)
            }
            return
        }
    }
}
