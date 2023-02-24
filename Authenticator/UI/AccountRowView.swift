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

    var body: some View {
            HStack {
                Text(String(account.title.first ?? "?"))
                    .frame(width:40, height: 40)
                    .background(account.iconColor)
                    .cornerRadius(20)
                VStack(alignment: .leading) {
                    Text(account.title).font(.headline).lineLimit(1).minimumScaleFactor(0.1)
                    account.subTitle.map {
                        Text($0).font(.footnote).lineLimit(1).minimumScaleFactor(0.1)
                    }
                }
                Spacer()
                HStack {
                    PieProgressView(progress: $account.remaining)
                        .frame(width: 22, height: 22)
                        .readFrame($statusIconFrame)
                    Text(account.formattedCode)
                        .font(Font.system(size: 17))
                        .bold()
                        .foregroundColor(.gray)
                        .padding(.trailing, 4)
                        .readFrame($codeFrame)
                }
                .padding(.all, 4)
                .overlay {
                    Capsule()
                        .stroke(Color.gray, lineWidth: 1)
                }

            }
            .listRowSeparator(.hidden)
            .onTapGesture {
                let data = AccountDetailsData(account: account, codeFrame: codeFrame, statusIconFrame: statusIconFrame, cellFrame: cellFrame)
                showAccountDetails = data
            }
            .readFrame($cellFrame)
            .onDisappear {
                account.resign()
            }
    }
}

struct PieProgressView: View {
    
    @Binding var progress: Double
    
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
