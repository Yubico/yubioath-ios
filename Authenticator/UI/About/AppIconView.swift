/*
 * Copyright (C) Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import SwiftUI

struct AppIconView: View {

    private struct AppIcon: Identifiable {
        // nil is the primary app icon, otherwise the name of an alternate Icon Composer (.icon) file.
        let iconName: String?
        let preview: String
        let title: String
        var id: String { iconName ?? "" }
    }

    private let icons = [
        AppIcon(iconName: nil, preview: "icon", title: String(localized: "Green", comment: "App icon name")),
        AppIcon(iconName: "AppIcon-Dark", preview: "icon-dark", title: String(localized: "Dark", comment: "App icon name"))
    ]

    @State private var selected = UIApplication.shared.alternateIconName
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(icons) { icon in
                Button {
                    select(icon)
                } label: {
                    HStack {
                        Image(icon.preview)
                            .resizable()
                            // Previews are rendered from the .icon files and already carry the system icon shape.
                            .frame(width: 60, height: 60)
                            .padding(.vertical, 4)
                            .accessibilityHidden(true)
                        Text(icon.title)
                            .foregroundColor(Color(.label))
                            .padding(.leading, 8)
                        Spacer()
                        if selected == icon.iconName {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .accessibilityAddTraits(selected == icon.iconName ? .isSelected : [])
            }
        }
        .navigationTitle(String(localized: "App icon", comment: "App icon navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "Failed to change app icon"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func select(_ icon: AppIcon) {
        guard selected != icon.iconName, UIApplication.shared.supportsAlternateIcons else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(icon.iconName)
                selected = icon.iconName
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
