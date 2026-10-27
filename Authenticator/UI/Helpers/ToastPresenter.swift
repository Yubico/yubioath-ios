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


@Observable class ToastPresenter {
    var isPresenting = false
    var message = "No message"
    
    @ObservationIgnored private var presentTask: Task<Void, any Error>?
    @ObservationIgnored private var dismissTask: Task<Void, any Error>?

    func toast(message: String) {
        presentTask?.cancel()
        dismissTask?.cancel()

        if isPresenting {
            isPresenting = false
            presentTask = Task { [weak self] in
                try await Task.sleep(for: .milliseconds(300))
                self?.present(message)
            }
        } else {
            present(message)
        }
    }

    private func present(_ message: String) {
        self.message = message
        isPresenting = true
        dismissTask = Task { [weak self] in
            try await Task.sleep(for: .seconds(4))
            self?.isPresenting = false
            self?.dismissTask = nil
        }
    }
}

extension ToastPresenter {
    
    func copyToClipboard(_ value: String) {
        UIPasteboard.general.string = value
        toast(message: String(localized: "Copied to clipboard", comment: "Toast copied to clipboard message"))
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
