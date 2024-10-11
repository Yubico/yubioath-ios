//
//  SettingsView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-29.
//  Copyright © 2024 Yubico. All rights reserved.
//

import SwiftUI

struct SettingsView<Content: View, Buttons: View>: View {
    
    var image: Image? = nil
    var imageColor: Color = .blue
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons
    
    var body: some View {
        VStack {
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    if let image {
                        image
                            .resizable()
                            .scaledToFit()
                            .font(Font.title.weight(.semibold))
                            .padding(10)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.white)
                            .background(imageColor)
                            .cornerRadius(13)
                            .padding(.top, 0)
                            .padding(.bottom, 0)
                            .accessibilityHidden(true)
                    }
                    content()
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 25)
                buttons()
            }
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(20)
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}
