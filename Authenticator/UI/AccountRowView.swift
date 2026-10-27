/*
 * Copyright (C) Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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

    @Environment(ToastPresenter.self) var toastPresenter
    var account: Account

    @State private var pillScaling: CGFloat = 1.0
    @State private var pillOpacity: Double

    @State private var animate: Bool = true

    // Hierarchical so the row stays legible when the list highlights it as selected.
    private let pillColor = HierarchicalShapeStyle.secondary
    
    init(account: Account) {
        self.account = account
        if account.state == .expired || account.otp == nil {
            self.pillOpacity = 0.5
        } else {
            self.pillOpacity = 1.0
        }
    }

    var body: some View {
            HStack {
                Text(String(account.title.first ?? "?"))
                    .frame(width:40, height: 40)
                    .background(account.iconColor)
                    .clipShape(.circle)
                    .padding(.trailing, 5)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text(account.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .truncationMode(.tail)
                    account.subTitle.map {
                        Text($0)
                            .font(.footnote)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .truncationMode(.tail)
                            .foregroundStyle(.secondary)
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
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 18))
                                .frame(width: 22.0, height: 22.0)
                                .padding(1)
                                .accessibilityHidden(true)
                        }
                    case .countingdown(let remaining):
                        PieProgressView(progress: remaining,
                                        color: pillColor,
                                        animate: animate)
                            .frame(width: 22, height: 22)
                            .padding(1)
                            .accessibilityHidden(true)
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
                        Text("888 888") // reserves the code width so the pill doesn't resize
                            .font(.system(size: 17))
                            .bold()
                            .foregroundStyle(.clear)
                            .padding(.trailing, 4)
                    }
                }
                .padding(.all, 4)
                .fixedSize() // keep the code on one line in a narrow sidebar; the title truncates instead
                .foregroundStyle(pillColor)
                .accessibilityAddTraits(.isButton)
                .overlay {
                    Capsule()
                        .stroke(pillColor, lineWidth: 1)
                }
                .accessibilityElement()
                .accessibilityLabel(account.state == .expired ? String(localized: "Code expired", comment: "Accessibility label") : account.formattedCode ?? String(localized: "Code not calculated", comment: "Accessibility label"))
                .opacity(pillOpacity)
                .scaleEffect(pillScaling)
            }
            .contentShape(Rectangle())
            .onChange(of: account.state) { _, state in
                // Not sure why we have to schedule this in the next runloop
                Task {
                    withAnimation {
                        if state == .expired || account.otp == nil {
                            pillOpacity = 0.5
                        } else {
                            pillOpacity = 1.0
                        }
                    }
                }
            }
            // Simultaneous so a tap still reaches the list and selects the row.
            .simultaneousGesture(LongPressGesture().onEnded { _ in
                Task {
                    withAnimation(.easeOut(duration: 0.1)) {
                        pillScaling = 1.4
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                    withAnimation(.easeInOut(duration: 0.25)) {
                        pillScaling = 1.0
                    }
                }

                if account.state != .expired, let otp = account.otp?.code {
                    toastPresenter.copyToClipboard(otp)
                } else {
                    account.calculate { otp in
                        toastPresenter.copyToClipboard(otp.code)
                    }
                }
            })
            .onAppear() {
                animate = true
            }
            .onDisappear {
                animate = false
            }
    }
}

struct PieProgressView<Style: ShapeStyle>: View {
    
    let progress: Double
    let color: Style
    let animate: Bool

    init(progress: Double, color: Style, animate: Bool = true) {
        self.progress = progress
        self.color = color
        self.animate = animate
    }

    var body: some View {
        var duration = progress >= 1.0 ? 0.0 : 1.0
        duration = animate ? duration : 0.0
        return PieShape(progress: self.progress)
            .foregroundStyle(color)
            .animation(.linear(duration: duration), value: self.progress)
    }
}

nonisolated private struct PieShape: Shape {

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
