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

struct MainView: View {
    
    @StateObject var model: MainViewModel
    
    var body: some View {
        NavigationView {
            List {
                ForEach(model.accounts, id: \.id) { account in
                    Text(account.name)
                }
            }
            .refreshable {
                model.refresh()
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !model.accountsLoaded {
                        Image("NavbarLogo")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 20)
                            .foregroundColor(Color("YubiGreen"))
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Menu") {
                        print("Show menu")
                    }
                }
            }
            .navigationTitle(model.accountsLoaded ? "Accounts" : "")
        }
    }
}
