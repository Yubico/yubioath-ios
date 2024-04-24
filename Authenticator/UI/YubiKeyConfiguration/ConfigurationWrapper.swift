//
//  ConfigurationWrapper.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-03-14.
//  Copyright © 2023 Yubico. All rights reserved.
//

import SwiftUI


struct ConfigurationView: View {
    
    @Binding var showConfiguration: Bool
    let navigationBarAppearance = UINavigationBarAppearance()

    init(showConfiguration: Binding<Bool> ) {
        navigationBarAppearance.shadowColor = .secondarySystemBackground
        navigationBarAppearance.backgroundColor = .secondarySystemBackground
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        _showConfiguration = showConfiguration
    }
    
    var body: some View {
        NavigationView {
            ConfigurationWrapper()
                .navigationTitle(String(localized: "Configuration", comment: "Configuration navigation title"))
                .navigationBarItems(trailing: Button(String(localized: "Close", comment: "View close button")) {
                    showConfiguration.toggle()
                })
                .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}

struct ConfigurationWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ConfigurationController {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "ConfigurationController") as! ConfigurationController
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ConfigurationController, context: Context) {
    }
    
    typealias UIViewControllerType = ConfigurationController
}

struct ConfigurationWrapper_Previews: PreviewProvider {
    static var previews: some View {
        ConfigurationWrapper()
    }
}
