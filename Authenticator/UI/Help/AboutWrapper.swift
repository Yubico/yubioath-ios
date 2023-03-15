//
//  HelpWrapper.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-03-15.
//  Copyright © 2023 Yubico. All rights reserved.
//

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
                .navigationTitle("About")
                .navigationBarItems(trailing: Button("Close") {
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
