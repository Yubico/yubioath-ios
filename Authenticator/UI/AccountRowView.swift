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


struct AccountRowView: View {

    @EnvironmentObject var toastPresenter: ToastPresenter
    @ObservedObject var account: Account
    @Binding var showAccountDetails: AccountDetailsData?
    @State private var contentSize: CGSize = .zero
    @State private var codeFrame: CGRect = .zero
    @State private var statusIconFrame: CGRect = .zero
    @State private var cellFrame: CGRect = .zero
    @State private var titleFrame: CGRect = .zero
    @State private var subTitleFrame: CGRect = .zero

    @State private var pillScaling: CGFloat = 1.0
    @State private var pillOpacity: Double = 1.0
    private let pillColor = Color(.secondaryLabel)

    var body: some View {
            HStack {
                Text(String(account.title.first ?? "?"))
                    .frame(width:40, height: 40)
                    .background(account.iconColor)
                    .cornerRadius(20)
                    .padding(.trailing, 5)
                VStack(alignment: .leading) {
                    Text(account.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                        .readFrame($titleFrame)
                    account.subTitle.map {
                        Text($0)
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .foregroundColor(Color(.secondaryLabel))
                            .readFrame($subTitleFrame)
                    }
                }
                Spacer()
                HStack {
                    switch(account.state) {
                    case .requiresCalculation, .expired:
                        if !account.requiresTouch {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 22))
                                .frame(width: 22.0, height: 22.0)
                                .padding(1)
                                .readFrame($statusIconFrame)
                        } else {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 18))
                                .frame(width: 22.0, height: 22.0)
                                .padding(1)
                                .readFrame($statusIconFrame)
                        }
                    case .countingdown(let remaining):
                        PieProgressView(progress: remaining, color: pillColor)
                            .frame(width: 22, height: 22)
                            .padding(1)
                            .readFrame($statusIconFrame)
                    }
                    ZStack {
                        if let otp = account.formattedCode {
                            Text(otp)
                                .font(.system(size: 17))
                                .bold()
                                .padding(.trailing, 4)
                        } else {
                            Text("*** *** ")
                                .font(.system(size: 17))
                                .bold()
                                .padding(.trailing, 4)
                                .padding(.top, 3.5)
                                .padding(.bottom, -3.5)
                        }
                        Text("888 888")
                            .font(.system(size: 17))
                            .bold()
                            .foregroundColor(.clear)
                            .padding(.trailing, 4)
                            .readFrame($codeFrame)
                    }
                }
                .foregroundColor(pillColor)
                .padding(.all, 4)
                .overlay {
                    Capsule()
                        .stroke(pillColor, lineWidth: 1)
                }
                .opacity(pillOpacity)
                .scaleEffect(pillScaling)
            }
            .listRowSeparator(.hidden)
            .background(Color(.systemBackground)) // without the background set, taps outside the Texts will be ignored
            .onTapGesture {
                let data = AccountDetailsData(account: account,
                                              codeFrame: codeFrame,
                                              statusIconFrame: statusIconFrame,
                                              cellFrame: cellFrame,
                                              titleFrame: titleFrame,
                                              subTitleFrame: subTitleFrame)
                showAccountDetails = data
            }
            .onChange(of: account.state) { state in
                // Not sure why we have to schedule this in the next runloop
                DispatchQueue.main.async {
                    withAnimation {
                        if state == .expired {
                            pillOpacity = 0.5
                        } else {
                            pillOpacity = 1.0
                        }
                    }
                }
            }
            .onLongPressGesture {
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.1)) {
                        pillScaling = 1.4
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            pillScaling = 1.0
                        }
                    }
                }

                if account.state != .expired, let otp = account.otp?.code {
                    toastPresenter.copyToClipboard(otp)
                } else {
                    account.calculate { otp in
                        toastPresenter.copyToClipboard(otp.code)
                    }
                }
            }
            .onDisappear {
                account.invalidate()
            }
            .readFrame($cellFrame)
    }
}

struct PieProgressView: View {
    
    var progress: Double
    var color: Color? = nil
    
    var body: some View {
        PieShape(progress: self.progress)
            .foregroundColor(color)
            .animation(.linear(duration: self.progress == 1.0 ? 0.0 : 1.0), value: self.progress)
    }
}

private struct PieShape: Shape {

    var animatableData: Double {
        get { self.progress }
        set { self.progress = newValue }
    }
    
    var progress: Double = 0.0
    private let start: Double = Double.pi * 1.5
    private var end: Double {
        get {
            return self.start - Double.pi * 2 * self.progress
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center =  CGPoint(x: rect.size.width / 2, y: rect.size.width / 2)
        let radius = rect.size.width / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: Angle(radians: start), endAngle: Angle(radians: end), clockwise: true)
        path.closeSubpath()
        return path
    }
}
