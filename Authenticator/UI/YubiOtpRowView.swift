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


struct YubiOtpRowView: View {

    @EnvironmentObject var toastPresenter: ToastPresenter
    var otp: String
    
    var body: some View {
        HStack {
            Image("yubikey")
                .frame(width:40, height: 40)
                .background(Color.accentColor)
                .cornerRadius(20)
                .padding(.trailing, 5)
            VStack(alignment: .leading) {
                Text(otp)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
            }
        }
        .listRowSeparator(.hidden)
        .background(Color(.systemBackground)) // without the background set, taps outside the Texts will be ignored
        .onTapGesture {
            toastPresenter.copyToClipboard(otp)
        }
        .onLongPressGesture {
            toastPresenter.copyToClipboard(otp)
        }
    }
}
