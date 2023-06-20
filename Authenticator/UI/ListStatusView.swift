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
    @State var showWhatsNew = false
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 25) {
                Spacer()
                image
                    .font(.system(size: 100.0))
                    .foregroundColor(Color(.yubiBlue))
                Text(message)
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .padding(EdgeInsets(top: 0, leading: 30, bottom: 0, trailing: 30))
                Spacer()
                if SettingsConfig.showWhatsNewText {
                    WhatsNewView(showWhatsNew: $showWhatsNew)
                }
            }
            Spacer()
        }
        .frame(height: height - 100)
        .listRowSeparator(.hidden)
        .sheet(isPresented: $showWhatsNew) {
            VersionHistoryView(title: "What's new in\nYubico Authenticator")
        }
    }
}

struct WhatsNewView: View {
    
    var text: AttributedString {
        var see = AttributedString("See ")
        see.foregroundColor = .secondaryLabel
        var whatsNew = AttributedString("what's new")
        whatsNew.foregroundColor = Color(.yubiBlue)
        var inThisVersion = AttributedString(" in this version")
        inThisVersion.foregroundColor = .secondaryLabel
        return see + whatsNew + inThisVersion
    }
    
    @Binding var showWhatsNew: Bool

    var body: some View {
        Button {
            showWhatsNew.toggle()
        } label: {
            Text(text).font(.footnote)
        }
    }
}

struct ListStatusViewView_Previews: PreviewProvider {
    static var previews: some View {
        ListStatusView(image: Image(systemName: "figure.surfing"), message: "Gone surfing, will be back tomorrow", height: 300)
    }
}
