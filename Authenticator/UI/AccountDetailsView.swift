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

struct AccountDetailsData: Equatable {
    static func == (lhs: AccountDetailsData, rhs: AccountDetailsData) -> Bool {
        lhs.account.id == rhs.account.id
    }
    
    @ObservedObject var account: Account
    let codeFrame: CGRect
    let statusIconFrame: CGRect
    let cellFrame: CGRect
}

struct AccountDetailsView: View {
    
    private let initialCodeFontSize = 17.0
    private let finalCodeFontSize = 30.0

    @EnvironmentObject var model: MainViewModel
    @Binding var data: AccountDetailsData?
    @ObservedObject var account: Account
    @State private var backgroundAlpha = 0.0
    @State private var codeOrigin: CGPoint
    @State private var statusIconOrigin: CGPoint
    @State private var modalAlpha: CGFloat
    @State private var modalRect: CGRect
    @State private var codeFontSize: CGFloat
    
    @State private var codeFrame: CGRect = .zero
    @State private var statusIconFrame: CGRect = .zero
    
    init(data: Binding<AccountDetailsData?>) {
        guard let detailsData = data.wrappedValue else { fatalError("Initializing AccountDetailsView while AccountDetailsData is nil is a fatal error.") }
        self._data = data
        account = detailsData.account
        codeOrigin = CGRect.adjustedPosition(from: detailsData.codeFrame)
        codeFontSize = initialCodeFontSize
        statusIconOrigin = CGRect.adjustedPosition(from: detailsData.statusIconFrame)
        modalRect = CGRect(origin: CGRect.adjustedPosition(from: detailsData.cellFrame), size: detailsData.cellFrame.size)
        modalAlpha = 0.1
    }
    
    var body: some View {
        if let data {
            GeometryReader { reader in
                ZStack {
                    Color.clear // full screen cover
                        .background(.ultraThinMaterial.opacity(backgroundAlpha))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation {
                                backgroundAlpha = 0
                                codeFontSize = initialCodeFontSize
                                // I have no idea where these two points are coming from
                                codeOrigin = CGRect.adjustedPosition(from: data.codeFrame, xAdjustment: -2)
                                statusIconOrigin = CGRect.adjustedPosition(from: data.statusIconFrame)
                                modalAlpha = 0.1
                                modalRect = CGRect(origin: CGRect.adjustedPosition(from: data.cellFrame), size: data.cellFrame.size)
                            }
                            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                self.data = nil
                            }
                        }
                    Color(.secondarySystemBackground) // details view background
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.15), radius: 3)
                        .opacity(modalAlpha)
                        .frame(width: modalRect.size.width, height: modalRect.size.height)
                        .position(modalRect.origin)
                        .ignoresSafeArea()
                    Text(data.account.formattedCode) // code
                        .font(Font.system(size: codeFontSize))
                        .bold()
                        .readFrame($codeFrame)
                        .foregroundColor(.gray)
                        .position(codeOrigin)
                        .ignoresSafeArea()
                    switch(account.state) {
                    case .requiresTouch:
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.gray)
                            .readFrame($statusIconFrame)
                            .position(statusIconOrigin)
                            .ignoresSafeArea()
                    case .calculate:
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.gray)
                            .readFrame($statusIconFrame)
                            .position(statusIconOrigin)
                            .ignoresSafeArea()
                    case .counter(let remaining):
                        PieProgressView(progress: remaining)
                            .frame(width: 22, height: 22)
                            .readFrame($statusIconFrame)
                            .position(statusIconOrigin)
                            .ignoresSafeArea()
                    }
                }.onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now()) { // we need to wait one runloop for the frames to be set
                        withAnimation {
                            backgroundAlpha = 1.0
                            codeFontSize = finalCodeFontSize
                            modalAlpha = 1
                            codeOrigin = CGPoint(x: reader.size.width / 2 + 5 + statusIconFrame.width / 2, y: reader.size.height / 2)
                            statusIconOrigin = CGPoint(x: (reader.size.width / 2) - (codeFrame.width * finalCodeFontSize / initialCodeFontSize) / 2 - 5, y: reader.size.height / 2)
                            modalRect = CGRect(x: reader.size.width / 2, y: reader.size.height / 2, width: 300, height: 120)
                        }
                    }
                }
            }
        }
    }
}

extension CGRect {
    static func adjustedPosition(from rect: CGRect, xAdjustment: CGFloat = 0.0) -> CGPoint {
        return CGPoint(x: rect.origin.x + rect.size.width / 2 + xAdjustment, y: rect.origin.y + rect.size.height / 2)
    }
}
