//
//  TokenRequestWrapper.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-06-22.
//  Copyright © 2023 Yubico. All rights reserved.
//

import SwiftUI

struct TokenRequestView: View {
    
    var userInfo: [AnyHashable: Any]?
    
    init(userInfo: [AnyHashable: Any]?) {
        self.userInfo = userInfo
    }
    
    var body: some View {
        TokenRequestWrapper(userInfo: userInfo)
    }
}

struct TokenRequestWrapper: UIViewControllerRepresentable {
    
    var userInfo: [AnyHashable: Any]?
    
    func makeUIViewController(context: Context) -> TokenRequestViewController {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(identifier: "TokenRequestViewController") as! TokenRequestViewController
        vc.userInfo = userInfo
        return vc
    }
    
    func updateUIViewController(_ uiViewController: TokenRequestViewController, context: Context) {
    }
    
    typealias UIViewControllerType = TokenRequestViewController
}
