/*
 * Copyright (C) Yubico.
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

public struct SettingsButton: View {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.displayScale) var displayScale
    
    private let text: String
    private let action: () -> Void
    
    public init(_ text: String, action: @escaping () -> Void) {
        self.text = text
        self.action = action
    }
    
    public var body: some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Color(.separator)
                    .frame(height: 1.0 / displayScale)
                    .frame(maxWidth: .infinity)
                    .padding(0)
                    .padding(.leading, 20)
                Text(text)
                    .font(.body)
                    .padding(12)
                    .padding(.leading, 7)
            }
        }
        .buttonStyle(SettingsButtonStyle(isEnabled: isEnabled))
    }
}

private struct SettingsButtonStyle: ButtonStyle {
    let isEnabled: Bool

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color(UIColor.systemGray4) : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isEnabled ? .blue : Color(.secondaryText))
    }
}
