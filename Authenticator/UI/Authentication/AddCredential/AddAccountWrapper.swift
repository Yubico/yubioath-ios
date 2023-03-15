//
//  AddCredentialWrapper.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-03-15.
//  Copyright © 2023 Yubico. All rights reserved.
//

import SwiftUI
import Combine

struct AddAccountView: View {
    
    @Binding var showAddAccount: Bool
    var accountSubject: PassthroughSubject<(YKFOATHCredentialTemplate, Bool), Never>
    let navigationBarAppearance = UINavigationBarAppearance()

    init(showAddCredential: Binding<Bool>, accountSubject: PassthroughSubject<(YKFOATHCredentialTemplate, Bool), Never>) {
        _showAddAccount = showAddCredential
        self.accountSubject = accountSubject
        navigationBarAppearance.shadowColor = .secondarySystemBackground
        navigationBarAppearance.backgroundColor = .secondarySystemBackground
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
    }
    
    var body: some View {
        AddCredentialWrapper(accountSubject: accountSubject)
            .navigationTitle("Add Credential")
            .navigationBarItems(trailing: Button("Close") {
                showAddAccount.toggle()
            })
            .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct AddCredentialWrapper: UIViewControllerRepresentable {
    
    var accountSubject: PassthroughSubject<(YKFOATHCredentialTemplate, Bool), Never>
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let sb = UIStoryboard(name: "AddCredential", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "AddCredentialController") as! UINavigationController
        
        guard let credentialController = vc.topViewController as? AddCredentialController else { fatalError() }
        
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
