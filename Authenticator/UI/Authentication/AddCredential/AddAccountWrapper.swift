/*
 * Copyright (C) Yubico.
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

import SwiftUI
import YubiKit
import Combine

struct AddAccountView: View {
    
    @Binding var showAddAccount: Bool
    var accountSubject: PassthroughSubject<(YubiKitOATHSession.CredentialTemplate?, Bool), Never>
    var oathURL: URL?

    init(showAddCredential: Binding<Bool>, accountSubject: PassthroughSubject<(YubiKitOATHSession.CredentialTemplate?, Bool), Never>, oathURL: URL?) {
        _showAddAccount = showAddCredential
        self.oathURL = oathURL
        self.accountSubject = accountSubject
    }
    
    // The wrapped storyboard navigation controller owns the bar and its Cancel and Save items.
    var body: some View {
        AddCredentialWrapper(accountSubject: accountSubject, oathURL: oathURL)
            .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct AddCredentialWrapper: UIViewControllerRepresentable {
    
    var accountSubject: PassthroughSubject<(YubiKitOATHSession.CredentialTemplate?, Bool), Never>
    var oathURL: URL?
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let sb = UIStoryboard(name: "AddCredential", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "AddCredentialController") as! UINavigationController
        
        guard let credentialController = vc.topViewController as? AddCredentialController else { fatalError() }
        if let oathURL {
            let template = try? YubiKitOATHSession.CredentialTemplate(otpauthURL: oathURL)
            credentialController.credential = template
        }
        
        credentialController.accountSubject = accountSubject
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
    
    typealias UIViewControllerType = UINavigationController
}
