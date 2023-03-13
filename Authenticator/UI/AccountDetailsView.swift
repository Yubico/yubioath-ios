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
    let titleFrame: CGRect
    let subTitleFrame: CGRect
}

struct AccountDetailsView: View {
    
    private let initialCodeFontSize = 17.0
    private let finalCodeFontSize = 30.0

    @EnvironmentObject var model: MainViewModel
    @Binding var data: AccountDetailsData?
    @ObservedObject var account: Account
    @State private var backgroundAlpha = 0.0
    @State private var titleOrigin: CGPoint
    @State private var subTitleOrigin: CGPoint
    @State private var codeOrigin: CGPoint
    @State private var codeBackgroundOrigin: CGPoint
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
        titleOrigin = CGRect.adjustedPosition(from: detailsData.titleFrame)
        subTitleOrigin = CGRect.adjustedPosition(from: detailsData.subTitleFrame)
        codeOrigin = CGRect.adjustedPosition(from: detailsData.codeFrame)
        codeBackgroundOrigin = CGRect.adjustedPosition(from: detailsData.cellFrame)
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
                                titleOrigin = CGRect.adjustedPosition(from: data.titleFrame)
                                subTitleOrigin = CGRect.adjustedPosition(from: data.subTitleFrame)
                                // I have no idea where these two points are coming from but a guess is the scale change has something to do with it
                                codeOrigin = CGRect.adjustedPosition(from: data.codeFrame, xAdjustment: -2)
                                codeBackgroundOrigin = CGRect.adjustedPosition(from: data.cellFrame)
                                statusIconOrigin = CGRect.adjustedPosition(from: data.statusIconFrame)
                                modalAlpha = 0.1
                                modalRect = CGRect(origin: CGRect.adjustedPosition(from: data.cellFrame), size: data.cellFrame.size)
                            }
                            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                self.data = nil
                            }
                        }
                    Color(.systemBackground) // details view background
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.15), radius: 3)
                        .opacity(modalAlpha)
                        .frame(width: modalRect.size.width, height: modalRect.size.height)
                        .position(modalRect.origin)
                        .ignoresSafeArea()
                    Color(.secondarySystemBackground) // Code background
                        .cornerRadius(10)
                        .opacity(modalAlpha)
                        .frame(width:modalRect.size.width - 30, height: 50)
                        .position(codeBackgroundOrigin)
                        .ignoresSafeArea()
                    Text(data.account.title) // Title
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                        .position(titleOrigin)
                        .ignoresSafeArea()
                    data.account.subTitle.map { // Subtitle
                        Text($0)
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .position(subTitleOrigin)
                            .ignoresSafeArea()
                    }
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
                    
                    DetachedMenu(menuActions: [
                        DetachedMenuAction(style: .default, isEnabled: account.enableRefresh, title: "Calculate", systemImage: "arrow.clockwise", action: {
                            self.account.requestRefresh.send(self.account)
                        }),
                        DetachedMenuAction(style: .default, isEnabled: !account.enableRefresh, title: "Copy", systemImage: "square.and.arrow.up", action: {
                            UIPasteboard.general.string = account.code
                        }),
                        DetachedMenuAction(style: .default, isEnabled: true, title: "Pin", systemImage: "pin", action: {
                            print("about")
                        }),
                        DetachedMenuAction(style: .destructive, isEnabled: true, title: "Delete", systemImage: "trash", action: {
                            print("delete")
                        })
                    ])
                    .position(CGPoint(x: reader.size.width / 2,
                                      y: reader.size.height / 2 + 120))
                    
                }.onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now()) { // we need to wait one runloop for the frames to be set
                        withAnimation {
                            backgroundAlpha = 1.0
                            codeFontSize = finalCodeFontSize
                            modalAlpha = 1
                            titleOrigin = CGPoint(x: reader.size.width / 2,
                                                  y: reader.size.height / 2 - (self.account.subTitle == nil ? 25 : 40))
                            subTitleOrigin = CGPoint(x: reader.size.width / 2,
                                                     y: reader.size.height / 2 - 15)
                            codeOrigin = CGPoint(x: reader.size.width / 2 + 5 + statusIconFrame.width / 2,
                                                 y: reader.size.height / 2 + 35)
                            codeBackgroundOrigin = CGPoint(x: reader.size.width / 2,
                                                           y: reader.size.height / 2 + 35)
                            statusIconOrigin = CGPoint(x: (reader.size.width / 2) - (codeFrame.width * finalCodeFontSize / initialCodeFontSize) / 2 - 5,
                                                       y: reader.size.height / 2 + 35)
                            modalRect = CGRect(x: reader.size.width / 2, y: reader.size.height / 2, width: 300, height: 150)
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
