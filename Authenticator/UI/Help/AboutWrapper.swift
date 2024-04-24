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


struct AboutView: View {
    
    @Binding var showAbout: Bool
    let navigationBarAppearance = UINavigationBarAppearance()

    init(showHelp: Binding<Bool> ) {
        navigationBarAppearance.shadowColor = .secondarySystemBackground
        navigationBarAppearance.backgroundColor = .secondarySystemBackground
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        _showAbout = showHelp
    }
    
    var body: some View {
        NavigationView {
            HelpWrapper()
                .navigationTitle(String(localized: "About", comment: "About view navigation title"))
                .navigationBarItems(trailing: Button(String(localized: "Close", comment: "View close button")) {
                    showAbout.toggle()
                })
                .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}

struct HelpWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HelpViewController {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "HelpViewController") as! HelpViewController
        return vc
    }
    
    func updateUIViewController(_ uiViewController: HelpViewController, context: Context) {
    }
    
    typealias UIViewControllerType = HelpViewController
}

struct HelpWrapper_Previews: PreviewProvider {
    static var previews: some View {
        HelpWrapper()
    }
}
