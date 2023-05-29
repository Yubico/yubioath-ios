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
import Combine

struct AddAccountView: View {
    
    @Binding var showAddAccount: Bool
    var accountSubject: PassthroughSubject<(YKFOATHCredentialTemplate?, Bool), Never>
    var oathURL: URL?
    let navigationBarAppearance = UINavigationBarAppearance()

    init(showAddCredential: Binding<Bool>, accountSubject: PassthroughSubject<(YKFOATHCredentialTemplate?, Bool), Never>, oathURL: URL?) {
        _showAddAccount = showAddCredential
        self.oathURL = oathURL
        self.accountSubject = accountSubject
        navigationBarAppearance.shadowColor = .secondarySystemBackground
        navigationBarAppearance.backgroundColor = .secondarySystemBackground
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
    }
    
    var body: some View {
        AddCredentialWrapper(accountSubject: accountSubject, oathURL: oathURL)
            .navigationTitle("Add Credential")
            .navigationBarItems(trailing: Button("Close") {
                showAddAccount.toggle()
            })
            .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct AddCredentialWrapper: UIViewControllerRepresentable {
    
    var accountSubject: PassthroughSubject<(YKFOATHCredentialTemplate?, Bool), Never>
    var oathURL: URL?
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let sb = UIStoryboard(name: "AddCredential", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "AddCredentialController") as! UINavigationController
        
        guard let credentialController = vc.topViewController as? AddCredentialController else { fatalError() }
        if let oathURL {
            let template = YKFOATHCredentialTemplate(url: oathURL)
            credentialController.credential = template
        }
        
        credentialController.accountSubject = accountSubject
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
    
    typealias UIViewControllerType = UINavigationController
}

struct AddCredentialWrapper_Previews: PreviewProvider {
    static var previews: some View {
        HelpWrapper()
    }
}
