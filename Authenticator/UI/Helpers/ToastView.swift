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

struct ToastView: View {
    
    let message: String
    
    @State var isVisible = true
    
    var body: some View {
        ZStack(alignment: .leading) {
            Text(message)
                .font(.body)
                .foregroundColor(Color(.white))
                .fixedSize(horizontal: true, vertical: true)
                .padding(EdgeInsets(top: 5, leading: 15, bottom: 5, trailing: 15))
                .background(Color(.yubiBlue))
                .cornerRadius(20)
                .shadow(radius: 5)
        }
    }
}

struct ToastModifier: ViewModifier {
    
    @Binding var isPresenting: Bool
    var message: String
    
    @ViewBuilder public func main() -> some View {
        if isPresenting {
            ToastView(message: message)
                .onTapGesture {
                    isPresenting = false
                }
                .transition(AnyTransition.scale(scale: 0.8).combined(with: .opacity))
        }
    }
    
    @ViewBuilder public func body(content: Content) -> some View {
        content
            .overlay(main(), alignment: .top)
            .animation(.spring(), value: isPresenting)
    }
}

public extension View {
    
    func toast(isPresenting: Binding<Bool>, message: String) -> some View {
        modifier(ToastModifier(isPresenting: isPresenting, message: message))
    }
    
}
