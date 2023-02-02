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

import SwiftUI

@main
struct AuthenticatorApp: App {
    
    @Environment(\.scenePhase) var scenePhase
    let mainViewModel = MainViewModel()
    
    var body: some Scene {
        WindowGroup {
            MainView(model: mainViewModel)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
                            YubiKitManager.shared.startAccessoryConnection()
                        }
                        if #available(iOS 16.0, *) {
                            YubiKitManager.shared.startSmartCardConnection()
                        }
                    } else if newPhase == .background {
                        if #available(iOS 16.0, *) {
                            YubiKitManager.shared.stopSmartCardConnection()
                        }
                    }
                }
        }
    }
}
