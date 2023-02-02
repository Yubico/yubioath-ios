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

import Foundation
import SwiftUI


struct Account {
    let id = UUID()
    let name: String
}

class MainViewModel: ObservableObject {
    
    @Published var accounts: [Account] = []
    @Published var accountsLoaded: Bool = false
    
    private let oathModel = OATHViewModel()
    
    init() {
        oathModel.delegate = self
    }
    
    func refresh() {
        oathModel.calculateAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.accountsLoaded = self.accounts.count > 0
        }
    }
}

extension MainViewModel: CredentialViewModelDelegate {
    
    func showAlert(title: String, message: String?) {
        print("showAlert")
    }
    
    func onError(error: Error) {
        print(error)
    }
    
    func onOperationCompleted(operation: OperationName) {
        accounts = oathModel.credentials.map { credential in
            Account(name: credential.formattedName)
        }
        self.accountsLoaded = self.accounts.count > 0

        print("onOperationCompleted")
    }
    
    func onShowToastMessage(message: String) {
        print("onShowToastMessage")
    }
    
    func onCredentialDelete(credential: Credential) {
        print("onCredentialDelete")
    }
    
    func collectPassword(isPasswordEntryRetry: Bool, completion: @escaping (String?) -> Void) {
        print("collectPassword")
    }
    
    func collectPasswordPreferences(completion: @escaping (PasswordSaveType) -> Void) {
        print("collectPasswordPreferences")
    }
}
