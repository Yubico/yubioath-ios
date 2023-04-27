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

class DetachedMenuAction: ObservableObject, Identifiable, Equatable {
    
    static func == (lhs: DetachedMenuAction, rhs: DetachedMenuAction) -> Bool {
        lhs.id == rhs.id
    }
    
    public enum Style {
        case `default`
        case destructive
    }
    
    @Published var isEnabled: Bool
    @Published var selected: Bool = false
    
    var frame: CGRect = .zero
    
    var id = UUID()
    var style: Style
    var title: String
    var systemImage: String
    var action: () -> Void
    
    init(style: Style, isEnabled: Bool, title: String, systemImage: String, action: @escaping () -> Void) {
        self.isEnabled = isEnabled
        self.style = style
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }
}



fileprivate struct DetachedMenuRow: View {
    
    @ObservedObject var action: DetachedMenuAction
    
    @State var rowFrame: CGRect = .zero // frame of DetachdeMenuRow is passed to the DetachdeMenuAction and in turn used by the DetachedMenu to figure out if the gesture ended inside the row.
    @State var selected: Bool = false
    
    var body: some View {
        let color: Color = action.style == .default ? Color(.label) : Color(.systemRed)
        HStack{
            Text(action.title).foregroundColor(color.opacity(action.isEnabled ? 1 : 0.4))
            Spacer()
            Image(systemName: action.systemImage).foregroundColor(color.opacity(action.isEnabled ? 1 : 0.4))
        }
        .padding(EdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15))
        .readFrame($rowFrame)
        .background(Color(action.selected ? .secondarySystemBackground : .systemBackground))
        .onChange(of: rowFrame, perform: { newFrame in
            action.frame = newFrame
        })
    }
}

struct DetachedMenu: View {
    
    var menuActions: [DetachedMenuAction]
    @State var scaling = 1.0
    @State var menuFrame: CGRect = .zero
    
    init(menuActions: [DetachedMenuAction]) {
        self.menuActions = menuActions
    }
    
    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 0) {
                ForEach(menuActions) { action in
                    DetachedMenuRow(action: action)
                    if action != menuActions.last {
                        Divider()
                    }
                }
            }
            .cornerRadius(12)
            .readFrame($menuFrame)
            Spacer()
        }
        .frame(width: 250)
        .shadow(color: .black.opacity(0.07), radius: 3)
        .scaleEffect(scaling, anchor: UnitPoint(x: 0.5, y: 0.0))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { change in
                    menuActions.forEach { action in
                        if !action.frame.contains(change.location) {
                            action.selected = false
                        } else if !action.selected {
                            action.selected = true
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    if let distance = menuFrame.distance(location: change.location), distance > 30 {
                        let newScale = max(1 - (distance - 30) / 700.0, 0.85)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            scaling = newScale
                        }
                    } else {
                        scaling = 1.0
                    }
                }
                .onEnded { status in
                    if scaling < 1.0 {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            scaling = scaling - 0.03
                        }
                        withAnimation(.easeInOut(duration: 0.2).delay(0.1)) {
                            scaling = 1.0
                        }                        }
                    menuActions.forEach { action in
                        if action.frame.contains(status.location) {
                            action.selected = false
                            if action.isEnabled {
                                action.action()
                            }
                        }
                    }
                }
        )
    }
}

extension CGRect {
    func distance(location: CGPoint) -> CGFloat? {
        if self.contains(location) {
            return nil
        } else {
            let y: CGFloat
            if location.y < self.origin.y { y = self.origin.y - location.y }
            else { y = location.y - (self.origin.y + self.height) }
            
            let x: CGFloat
            if location.x < self.origin.x { x = self.origin.x - location.x }
            else { x = location.x - (self.origin.x + self.width) }
            
            return max(x, y)
        }
    }
}
