//
//  EmptyListView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-03-29.
//  Copyright © 2023 Yubico. All rights reserved.
//

import SwiftUI

struct EmptyListView: View {
    
    let height: CGFloat
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 25) {
                Spacer()
                Image("yubikey")
                    .font(.system(size: 100.0))
                    .foregroundColor(Color("YubiBlue"))
                Text("Insert YubiKey or pull down to activate NFC")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
                Spacer()
            }
            Spacer()
        }
        .frame(height: height - 100)
        .listRowSeparator(.hidden)
    }
}
