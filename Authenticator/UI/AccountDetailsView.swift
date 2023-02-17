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

struct AccountDetailsData {
    let account: Account
    let codeFrame: CGRect
    let cellFrame: CGRect
}

struct AccountDetailsView: View {
    
    @EnvironmentObject var model: MainViewModel
    @Binding var data: AccountDetailsData?
    @State private var backgroundAlpha = 0.0
    @State private var codeOrigin: CGPoint
    @State private var modalAlpha: CGFloat
    @State private var modalRect: CGRect
    @State private var codeFontSize: CGFloat
    
    init(data: Binding<AccountDetailsData?>) {
        self._data = data
        codeOrigin = CGRect.adjustedPosition(from: data.wrappedValue?.codeFrame)
        codeFontSize = 17
        modalRect = CGRect(origin: CGRect.adjustedPosition(from: data.wrappedValue?.cellFrame), size: data.wrappedValue?.cellFrame.size ?? .zero)
        modalAlpha = 0.1
        print("cellFrame: \(modalRect)")
    }
    
    var body: some View {
        if let data {
            GeometryReader { reader in
                ZStack {
                    Color.clear
                        .background(.ultraThinMaterial.opacity(backgroundAlpha))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                backgroundAlpha = 0
                                codeFontSize = 17
                                codeOrigin = CGRect.adjustedPosition(from: data.codeFrame)
                                modalAlpha = 0.1
                                modalRect = CGRect(origin: CGRect.adjustedPosition(from: data.cellFrame), size: data.cellFrame.size)
                            }
                            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                self.data = nil
                            }
                        }
                    Color(.secondarySystemBackground)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.2), radius: 3)
                        .opacity(modalAlpha)
                        .frame(width: modalRect.size.width, height: modalRect.size.height)
                        .position(modalRect.origin)
                        .ignoresSafeArea()
                    Text(data.account.formattedCode)
                        .font(Font.system(size: codeFontSize))
                        .bold()
                        .foregroundColor(.gray)
                        .position(codeOrigin)
                        .ignoresSafeArea()
                    
                }.onAppear {
                    withAnimation {
                        backgroundAlpha = 1.0
                        codeFontSize = 30
                        modalAlpha = 1
                        codeOrigin = CGPoint(x: reader.size.width / 2 , y: reader.size.height / 2)
                        modalRect = CGRect(x: reader.size.width / 2, y: reader.size.height / 2, width: 300, height: 120)
                    }
                }
            }
        }
    }
}

extension CGRect {
    static func adjustedPosition(from rect: CGRect?) -> CGPoint {
        guard let rect else { return .zero }
        // I have no idea where these two points are coming from
        return CGPoint(x: rect.origin.x + rect.size.width / 2 - 2, y: rect.origin.y + rect.size.height / 2)
    }
}
