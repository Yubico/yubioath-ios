//
//  SettingsView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2024-08-29.
//  Copyright © 2024 Yubico. All rights reserved.
//  Copyright © 2026 Kenzi Voyer.
//

import SwiftUI

struct SettingsView<Content: View, Buttons: View>: View {
    
    var image: Image? = nil
    var imageColor: Color = .blue
    @ViewBuilder var content: () -> Content
    @ViewBuilder var buttons: () -> Buttons
    
    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    if let image {
                        image
                            .resizable()
                            .scaledToFit()
                            .font(Font.title.weight(.semibold))
                            .padding(10)
                            .frame(width: 60, height: 60)
                            .foregroundStyle(.white)
                            .background(imageColor)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .accessibilityHidden(true)
                    }
                    content()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                buttons()
            }
        }
        .formStyle(.grouped)
    }
}
