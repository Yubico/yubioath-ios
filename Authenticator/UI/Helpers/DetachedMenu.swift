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

struct DetachedMenuAction: View, Identifiable, Equatable {
    
    static func == (lhs: DetachedMenuAction, rhs: DetachedMenuAction) -> Bool {
        lhs.id == rhs.id
    }
    
    public enum Style {
        case `default`
        case destructive
    }
    
    var id = UUID()
    var style: Style
    @State var isEnabled: Bool
    var title: String
    var systemImage: String
    var action: () -> Void
    
    var body: some View {
        let color: Color = style == .default ? .black : .red
        Button {
            action()
        } label: {
            HStack{
                Text(title).foregroundColor(color.opacity(isEnabled ? 1 : 0.3))
                Spacer()
                Image(systemName: systemImage).foregroundColor(color.opacity(isEnabled ? 1 : 0.3))
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
        }
        .disabled(!isEnabled)
    }
}

struct DetachedMenu: View {

    var menuActions: [DetachedMenuAction]
    
    init(menuActions: [DetachedMenuAction]) {
        self.menuActions = menuActions
    }
    
    var body: some View {

        HStack {
            Spacer()
            VStack(spacing: 0) {
                ForEach(menuActions) { action in
                    action
                    if action != menuActions.last {
                        Divider()
                    }
                }
            }
            .cornerRadius(10)
            Spacer()
        }
        .frame(width: 250)
        .shadow(color: .black.opacity(0.15), radius: 3)
    }
}

struct DetachedMenu_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            DetachedMenu(menuActions: [
                DetachedMenuAction(style: .default, isEnabled: false, title: "Calculate", systemImage: "arrow.clockwise", action: { } ),
                DetachedMenuAction(style: .default, isEnabled: true, title: "Pin", systemImage: "pin", action: { } ),
                DetachedMenuAction(style: .destructive, isEnabled: true, title: "Delete", systemImage: "trash", action: { } ),
            ])
        }
    }
}
