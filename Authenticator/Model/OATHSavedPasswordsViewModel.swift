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


import OSLog

class OATHSavedPasswordsViewModel: ObservableObject {

    @Published var state: ResetState = .ready
    
    enum ResetState: Equatable {
        case ready, success, error(String)
    }
    
    private let connection = Connection()

    func clearPasswords() {
        
        let passwordPreferences = PasswordPreferences()
        let secureStore = SecureStore(secureStoreQueryable: PasswordQueryable(service: "OATH"))
        passwordPreferences.resetPasswordPreferenceForAll()
        do {
            try secureStore.removeAllValues()
            self.state = .success
        } catch {
            self.state = .error(error.localizedDescription)
        }
    }

    init() {
        Logger.allocation.debug("OATHSavedPasswordsViewModel: init")
    }
    
    deinit {
        Logger.allocation.debug("OATHSavedPasswordsViewModel: deinit")
    }
}
