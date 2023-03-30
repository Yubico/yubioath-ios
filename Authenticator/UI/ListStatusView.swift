//
//  EmptyListView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2023-03-29.
//  Copyright © 2023 Yubico. All rights reserved.
//

import SwiftUI

struct ListStatusView: View {
    
    let image: Image
    let message: String
    let height: CGFloat
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 25) {
                Spacer()
                image
                    .font(.system(size: 100.0))
                    .foregroundColor(Color("YubiBlue"))
                Text(message)
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

struct ListStatusViewView_Previews: PreviewProvider {
    static var previews: some View {
        ListStatusView(image: Image(systemName: "figure.surfing"), message: "Gone surfing, will be back tomorrow", height: 300)
    }
}
