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


struct EditView: View {
    
    @Binding var showEditing: Bool
    
    let viewModel: MainViewModel
    let account: Account
    
    let navigationBarAppearance = UINavigationBarAppearance()

    init(account: Account, viewModel: MainViewModel, showEditing: Binding<Bool> ) {
        self.account = account
        self.viewModel = viewModel
        _showEditing = showEditing
        navigationBarAppearance.shadowColor = .secondarySystemBackground
        navigationBarAppearance.backgroundColor = .secondarySystemBackground
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
    }
    
    var body: some View {
        EditAccountWrapper(account: account, viewModel: viewModel)
            .ignoresSafeArea(.all, edges: .bottom)
    }
}

struct EditAccountWrapper: UIViewControllerRepresentable {
    
    
    let account: Account
    let viewModel: MainViewModel
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let sb = UIStoryboard(name: "EditCredential", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "EditCredentialController") as! UINavigationController
        
        guard let editCredentialController = vc.topViewController as? EditCredentialController else { fatalError() }
        editCredentialController.account = account
        editCredentialController.viewModel = viewModel
        
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
    }
    
    typealias UIViewControllerType = UINavigationController
}

