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


extension View {
    func readFrame(_ frame: Binding<CGRect>) -> some View {
        self.modifier(FrameReaderModifier(frame: frame))
    }
}

struct FrameReaderModifier: ViewModifier  {
    @Binding var frame: CGRect
    
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry -> Color in
                DispatchQueue.main.async {
                    frame = geometry.frame(in: CoordinateSpace.global)
                }
                return Color.clear
            }
        )
    }
}


extension View {
    func readSize(_ size: Binding<CGSize>) -> some View {
        self.modifier(SizeReaderModifier(size: size))
    }
}

struct SizeReaderModifier: ViewModifier  {
    @Binding var size: CGSize
    
    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geometry -> Color in
                DispatchQueue.main.async {
                    size = geometry.size
                }
                return Color.clear
            }
        )
    }
}


extension View {
    @ViewBuilder func refreshable(enabled: Bool, action: @escaping () async -> Void) -> some View {
        if enabled {
            self.refreshable {
                await action()
            }
        } else {
            self
        }
    }
}
