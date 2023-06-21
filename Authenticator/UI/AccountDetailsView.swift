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
        lhs.account.accountId == rhs.account.accountId
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
    @EnvironmentObject var toastPresenter: ToastPresenter
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
    @State private var menuAlpha: CGFloat = 0.0
    @State private var menuScale: CGFloat = 0.3
    
    @State private var showEditing = false
    @State private var showDeleteConfirmation = false

    @State private var codeFrame: CGRect = .zero
    @State private var statusIconFrame: CGRect = .zero
    @State private var menuFrame: CGRect = .zero
    
    @State private var codeOpacity: Double
    private let codeColor = Color(.secondaryLabel)
    
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
        if detailsData.account.state == .expired {
            codeOpacity = 0.4
        } else {
            codeOpacity = 1.0
        }
    }
    
    var body: some View {
        if let data {
            GeometryReader { reader in
                ZStack {
                    Color.clear // full screen cover
                        .background(.ultraThinMaterial.opacity(backgroundAlpha))
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                backgroundAlpha = 0.0
                                codeFontSize = initialCodeFontSize
                                titleOrigin = CGRect.adjustedPosition(from: data.titleFrame)
                                subTitleOrigin = CGRect.adjustedPosition(from: data.subTitleFrame)
                                // I have no idea where these two points are coming from but a guess is the scale change has something to do with it
                                codeOrigin = CGRect.adjustedPosition(from: data.codeFrame, xAdjustment: -2.0)
                                codeBackgroundOrigin = CGRect.adjustedPosition(from: data.cellFrame)
                                statusIconOrigin = CGRect.adjustedPosition(from: data.statusIconFrame)
                                modalAlpha = 0.1
                                modalRect = CGRect(origin: CGRect.adjustedPosition(from: data.cellFrame), size: data.cellFrame.size)
                            }
                            withAnimation(.easeInOut(duration: 0.15)) {
                                menuScale = 0.3
                                menuAlpha = 0.0
                            }
                            
                            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                self.data = nil
                            }
                        }
                    Color(.systemBackground) // details view background
                        .cornerRadius(15.0)
                        .shadow(color: .black.opacity(0.07), radius: 3.0)
                        .opacity(modalAlpha)
                        .frame(width: modalRect.size.width, height: modalRect.size.height)
                        .position(modalRect.origin)
                        .ignoresSafeArea()
                    Color(.secondarySystemBackground) // Code background
                        .cornerRadius(10.0)
                        .opacity(modalAlpha)
                        .frame(width:modalRect.size.width - 30.0, height: 50.0)
                        .position(codeBackgroundOrigin)
                        .ignoresSafeArea()
                    Text(data.account.title) // Title
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                        .position(titleOrigin)
                        .ignoresSafeArea()
                    data.account.subTitle.map { // Subtitle
                        Text($0)
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .foregroundColor(Color(.secondaryLabel))
                            .position(subTitleOrigin)
                            .ignoresSafeArea()
                    }
                    
                    ZStack {
                        if let otp = data.account.formattedCode {
                            Text(otp) // code
                                .font(Font.system(size: codeFontSize))
                                .bold()
                                .foregroundColor(codeColor)
                                .opacity(codeOpacity)
                                .position(codeOrigin)
                                .ignoresSafeArea()
                        } else {
                            Text("*** *** ")
                                .font(Font.system(size: codeFontSize))
                                .bold()
                                .foregroundColor(codeColor)
                                .opacity(codeOpacity)
                                .position(codeOrigin)
                                .padding(.top, 4)
                                .ignoresSafeArea()
                        }
                        Text("888 888")
                            .font(Font.system(size: codeFontSize))
                            .bold()
                            .foregroundColor(.clear)
                            .readFrame($codeFrame)
                            .position(codeOrigin)
                            .ignoresSafeArea()
                    }
                    switch(account.state) {
                    case .requiresCalculation, .expired:
                        if !account.requiresTouch {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 22.0))
                                .foregroundStyle(codeColor)
                                .opacity(codeOpacity)
                                .frame(width: 22.0, height: 22.0)
                                .readFrame($statusIconFrame)
                                .position(statusIconOrigin)
                                .ignoresSafeArea()
                        } else {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 18.0))
                                .foregroundStyle(codeColor)
                                .opacity(codeOpacity)
                                .frame(width: 22.0, height: 22.0)
                                .readFrame($statusIconFrame)
                                .position(statusIconOrigin)
                                .ignoresSafeArea()
                        }
                    case .countingdown(let remaining):
                        PieProgressView(progress: remaining, color: codeColor)
                            .frame(width: 22.0, height: 22.0)
                            .readFrame($statusIconFrame)
                            .position(statusIconOrigin)
                            .opacity(codeOpacity)
                            .ignoresSafeArea()
                    }
                    
                    DetachedMenu(menuActions: [
                        DetachedMenuAction(style: .default, isEnabled: account.enableRefresh, title: "Calculate", systemImage: "arrow.clockwise", action: {
                            self.account.calculate()
                        }),
                        DetachedMenuAction(style: .default, isEnabled: account.state != .expired && account.otp != nil, title: "Copy", systemImage: "square.and.arrow.up", action: {
                            guard let otp = account.otp?.code else { return }
                            toastPresenter.copyToClipboard(otp)
                        }),
                        DetachedMenuAction(style: .default, isEnabled: true, title: account.isPinned ? "Unpin" : "Pin", systemImage: "pin", action: {
                            account.isPinned.toggle()
                        }),
                        account.keyVersion >= YKFVersion(string: "5.3.0") ? DetachedMenuAction(style: .default, isEnabled: true, title: "Rename", systemImage: "square.and.pencil", action: {
                            showEditing.toggle()
                        }) : nil,
                        DetachedMenuAction(style: .destructive, isEnabled: true, title: "Delete", systemImage: "trash", action: {
                            showDeleteConfirmation = true
                        })
                    ].compactMap { $0 } )
                    .readFrame($menuFrame)
                    .position(CGPoint(x: reader.size.width / 2.0,
                                      y: reader.size.height / 2.0 + 2.0 + menuFrame.size.height / 2.0 + 40.0))
                    .opacity(menuAlpha)
                    .scaleEffect(menuScale, anchor: UnitPoint(x: 0.5, y: 0.5))
                    
                }
                .sheet(isPresented: $showEditing) {
                    EditView(account: account, viewModel: model, showEditing: $showEditing)
                }
                .alert(isPresented: $showDeleteConfirmation) {
                    Alert(title: Text("Delete account?"),
                          message: Text("This will permanently delete the account from the YubiKey, and your ability to generate codes for it!"),
                          primaryButton: .default(Text("Cancel")),
                          secondaryButton: .destructive(
                            Text("Delete"),
                            action: {
                                model.deleteAccount(account) {
                                    self.data = nil
                                }
                            }
                          )
                    )
                }
                .onChange(of: model.accountsLoaded) { newValue in
                    self.data = nil
                }
                .onChange(of: account.state) { state in
                    DispatchQueue.main.async {
                        withAnimation {
                            if state == .expired {
                                codeOpacity = 0.4
                            } else {
                                codeOpacity = 1.0
                            }
                        }
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now()) { // we need to wait one runloop for the frames to be set
                        withAnimation(.easeInOut(duration: 0.3)) {
                            backgroundAlpha = 1.0
                            codeFontSize = finalCodeFontSize
                            modalAlpha = 1.0
                            titleOrigin = CGPoint(x: reader.size.width / 2.0,
                                                  y: reader.size.height / 2.0 - (self.account.subTitle == nil ? 25.0 : 40.0))
                            subTitleOrigin = CGPoint(x: reader.size.width / 2.0,
                                                     y: reader.size.height / 2.0 - 15.0)
                            codeOrigin = CGPoint(x: reader.size.width / 2.0 + 5.0 + statusIconFrame.width / 2.0,
                                                 y: reader.size.height / 2.0 + 35.0)
                            codeBackgroundOrigin = CGPoint(x: reader.size.width / 2.0,
                                                           y: reader.size.height / 2.0 + 35.0)
                            statusIconOrigin = CGPoint(x: (reader.size.width / 2.0) - (codeFrame.width * finalCodeFontSize / initialCodeFontSize) / 2.0 - 5.0,
                                                       y: reader.size.height / 2.0 + 35.0)
                            modalRect = CGRect(x: reader.size.width / 2.0, y: reader.size.height / 2.0, width: 300.0, height: 150.0)
                        }
                    }
                    withAnimation(.easeInOut(duration: 0.15).delay(0.2)) {
                        menuAlpha = 1.0
                        menuScale = 1.0
                    }
                }
            }
        }
    }
}

extension CGRect {
    static func adjustedPosition(from rect: CGRect, xAdjustment: CGFloat = 0.0) -> CGPoint {
        return CGPoint(x: rect.origin.x + rect.size.width / 2.0 + xAdjustment, y: rect.origin.y + rect.size.height / 2.0)
    }
}
