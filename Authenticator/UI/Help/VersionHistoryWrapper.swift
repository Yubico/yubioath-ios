//
//  VersionHistoryWrapper.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-06-20.
//  Copyright © 2023 Yubico. All rights reserved.
//

import SwiftUI

struct VersionHistoryView: View {
    
    let title: String
    
    var body: some View {
        VersionHistoryWrapper(title: title)
    }
}

struct VersionHistoryWrapper: UIViewControllerRepresentable {
    
    let title: String
    
    func makeUIViewController(context: Context) -> VersionHistoryViewController {
        let vc = VersionHistoryViewController()
        vc.titleText = title
        return vc
    }
    
    func updateUIViewController(_ uiViewController: VersionHistoryViewController, context: Context) {
    }
    
    typealias UIViewControllerType = VersionHistoryViewController
}
