//
//  SettingsView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-29.
//  Copyright © 2024 Yubico. All rights reserved.
//

import SwiftUI

struct SettingsView<Image: View, Content: View, Buttons: View>: View {
    
    var image: Image? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons
    
    var body: some View {
        VStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    if let image {
                        image
                            .font(.system(size:50.0))
                            .foregroundColor(Color(.yubiBlue))
                            .accessibilityHidden(true)
                    }
                    content()
                }
                .padding(30)
                buttons()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .padding(20)
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}
