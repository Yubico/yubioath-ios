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


class ToastPresenter: ObservableObject {
    @Published var isPresenting = false
    @Published var message = "No message"
    
    private var presentWorkItem: DispatchWorkItem?
    private var dismissWorkItem: DispatchWorkItem?
    
    func toast(message: String) {
        presentWorkItem?.cancel()
        dismissWorkItem?.cancel()
        
        if isPresenting {
            isPresenting = false
            let task = DispatchWorkItem {
                self.present(message)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
            dismissWorkItem = task
        } else {
            present(message)
        }
    }
    
    private func present(_ message: String) {
        self.message = message
        isPresenting = true
        let task = DispatchWorkItem {
            self.isPresenting = false
            self.presentWorkItem = nil
        }
        presentWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: task)
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
