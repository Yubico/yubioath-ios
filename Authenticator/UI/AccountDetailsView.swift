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
import YubiKit

// Detail column of the main split view. Shown beside the account list in regular width
// (iPad, iPhone Duo inner display) and pushed on top of it in compact width.
struct AccountDetailView: View {

    @Environment(MainViewModel.self) var model
    @Environment(ToastPresenter.self) var toastPresenter
    let account: Account
    let onDelete: () -> Void

    @State private var showEditing = false
    @State private var showDeleteConfirmation = false

    private let codeColor = Color(.secondaryLabel)
    @ScaledMetric(relativeTo: .largeTitle) private var codeFontSize: CGFloat = 44

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(String(account.title.first ?? "?"))
                .font(.largeTitle)
                .frame(width: 80, height: 80)
                .background(account.iconColor)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text(account.title)
                .font(.title2.weight(.medium))
                .multilineTextAlignment(.center)
            account.subTitle.map {
                Text($0)
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
            }
            Button(action: copyCode) {
                HStack(spacing: 10) {
                    statusIcon
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                    // Scales with Dynamic Type, and shrinks rather than truncating or wrapping in a narrow column such as
                    // Slide Over or half of a folded iPhone Duo.
                    Text(account.formattedCode ?? "*** ***")
                        .font(.system(size: codeFontSize, weight: .bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .opacity(account.state == .expired ? 0.4 : 1.0)
                }
                .foregroundStyle(codeColor)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)
            .accessibilityLabel(account.state == .expired ? String(localized: "Code expired", comment: "Accessibility label") : account.formattedCode ?? String(localized: "Code not calculated", comment: "Accessibility label"))
            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .avoidingReservedRegions()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: copyCode) {
                    Label(String(localized: "Copy", comment: "Menu"), systemImage: "doc.on.doc")
                }
                .disabled(account.state == .expired || account.otp == nil)
                Button(action: { account.calculate() }) {
                    Label(String(localized: "Calculate", comment: "Menu"), systemImage: "arrow.clockwise")
                }
                .disabled(!account.enableRefresh)
                Button(action: { account.isPinned.toggle() }) {
                    Label(account.isPinned ? String(localized: "Unpin", comment: "Menu") : String(localized: "Pin", comment: "Menu"),
                          systemImage: account.isPinned ? "pin.slash" : "pin")
                }
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                if account.keyVersion >= Version("5.3.0")! {
                    Button(action: { showEditing.toggle() }) {
                        Label(String(localized: "Rename", comment: "Menu"), systemImage: "square.and.pencil")
                    }
                }
                Button(role: .destructive, action: { showDeleteConfirmation = true }) {
                    Label(String(localized: "Delete", comment: "Menu"), systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showEditing) {
            EditView(account: account, viewModel: model, showEditing: $showEditing)
        }
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                model.deleteAccount(account) {
                    onDelete()
                }
            }
        } message: {
            Text("This will permanently delete the account from the YubiKey, and your ability to generate codes for it!")
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch account.state {
        case .requiresCalculation, .expired:
            Image(systemName: account.requiresTouch ? "hand.tap.fill" : "arrow.clockwise.circle.fill")
                .font(.system(size: 26))
        case .countingdown(let remaining):
            PieProgressView(progress: remaining, color: codeColor)
        }
    }

    private func copyCode() {
        if account.state != .expired, let otp = account.otp?.code {
            toastPresenter.copyToClipboard(otp)
        } else {
            account.calculate { otp in
                toastPresenter.copyToClipboard(otp.code)
            }
        }
    }
}
