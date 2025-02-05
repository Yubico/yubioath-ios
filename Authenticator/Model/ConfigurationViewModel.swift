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

import SwiftUI
import OSLog

class ConfigurationViewModel: ObservableObject {

    let connection = Connection()
    
    @Published var deviceInfo: YKFManagementDeviceInfo? {
        didSet {
            resetDeviceInfoTask?.cancel()
            resetDeviceInfoTask = nil
        }
    }
    
    var resetDeviceInfoTask: Task<Void, Error>?
    
    init() {
        Logger.allocation.debug("ConfigurationViewModel: init")
    }
    
    func waitForConnection() {
        Logger.connection.debug("ConfigurationViewModel: waitForConnection")
        connection.startWiredConnection { [weak self] connection in
            Logger.connection.debug("ConfigurationViewModel: got wired connection")
            connection.managementSession { session, error in
                guard let session else { Logger.connection.error("ConfigurationviewModel: got error: \(error)"); return }
                session.getDeviceInfo { info, error in
                    guard let info else { Logger.connection.error("ConfigurationviewModel: got error: \(error)"); return }
                    DispatchQueue.main.async {
                        self?.deviceInfo = info
                    }
                }
            }
            
            self?.connection.didDisconnect { [weak self] connection, error in
                DispatchQueue.main.async {
                    self?.deviceInfo = nil
                }
                self?.waitForConnection()
            }
        }

    }
    
    func start() {
        resetDeviceInfoTask = Task.detached {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            Task.detached { @MainActor in
                self.deviceInfo = nil
            }
        }
        waitForConnection()
    }
    
    func scanNFC() {
        connection.startConnection { [weak self] connection in
            connection.managementSession() { session, error in
                guard let session else { Logger.connection.error("ConfigurationviewModel: got error: \(error)"); return }
                session.getDeviceInfo { info, error in
                    DispatchQueue.main.async {
                        self?.deviceInfo = info
                        YubiKitManager.shared.stopNFCConnection(withMessage: String(localized: "Configuration read", comment: "NFC connection stopped message."))
                    }
                }
            }
        }
    }
    
    deinit {
        Logger.allocation.debug("ConfigurationViewModel: deinit")
    }
}
