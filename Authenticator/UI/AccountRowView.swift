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

    @ObservedObject var account: Account
    @Binding var showAccountDetails: AccountDetailsData?
    @State private var contentSize: CGSize = .zero
    @State private var codeFrame: CGRect = .zero
    @State private var statusIconFrame: CGRect = .zero
    @State private var cellFrame: CGRect = .zero
    @State private var titleFrame: CGRect = .zero
    @State private var subTitleFrame: CGRect = .zero

    var body: some View {
            HStack {
                Text(String(account.title.first ?? "?"))
                    .frame(width:40, height: 40)
                    .background(account.iconColor)
                    .cornerRadius(20)
                VStack(alignment: .leading) {
                    Text(account.title).font(.headline).lineLimit(1).minimumScaleFactor(0.1)
                        .readFrame($titleFrame)
                    account.subTitle.map {
                        Text($0).font(.footnote).lineLimit(1).minimumScaleFactor(0.1)
                            .readFrame($subTitleFrame)
                    }
                }
                Spacer()
                HStack {
                    switch(account.state) {
                    case .requiresTouch:
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.gray)
                            .frame(width: 22.0, height: 22.0)
                            .readFrame($statusIconFrame)
                    case .calculate:
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.gray)
                            .frame(width: 22.0, height: 22.0)
                            .readFrame($statusIconFrame)
                    case .counter(let remaining):
                        PieProgressView(progress: remaining)
                            .frame(width: 22, height: 22)
                            .readFrame($statusIconFrame)
                    }
                    ZStack {
                        if let otp = account.formattedCode {
                            Text(otp)
                                .font(.system(size: 17))
                                .bold()
                                .foregroundColor(.gray)
                                .padding(.trailing, 4)
                        } else {
                            Text("*** *** ")
                                .font(.system(size: 17))
                                .bold()
                                .foregroundColor(.gray)
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
                .padding(.all, 4)
                .overlay {
                    Capsule()
                        .stroke(Color.gray, lineWidth: 1)
                }

            }
            .listRowSeparator(.hidden)
            .onTapGesture {
                let data = AccountDetailsData(account: account,
                                              codeFrame: codeFrame,
                                              statusIconFrame: statusIconFrame,
                                              cellFrame: cellFrame,
                                              titleFrame: titleFrame,
                                              subTitleFrame: subTitleFrame)
                showAccountDetails = data
            }
            .readFrame($cellFrame)
            .onDisappear {
                account.resign()
            }
    }
}

struct PieProgressView: View {
    
    var progress: Double
    
    var body: some View {
        PieShape(progress: self.progress)
            .foregroundColor(.gray)
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
