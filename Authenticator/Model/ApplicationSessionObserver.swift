/*
 * Copyright (C) 2022 Yubico.
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

import Foundation

protocol ApplicationSessionObserverDelegate: NSObjectProtocol {
    func didEnterBackground()
    func willResignActive()
    func didBecomeActive()
}

// Default implementations making the methods optional when implementing ApplicationSessionObserverDelegate
extension ApplicationSessionObserverDelegate {
    func didEnterBackground() {
        // do nothing
    }
    func willResignActive() {
        // do nothing
    }
    func didBecomeActive() {
        // do nothing
    }
}

@objc class ApplicationSessionObserver: NSObject {

private weak var applicationDelegate: ApplicationSessionObserverDelegate?
    let notificationCenter = NotificationCenter.default

    init(delegate: ApplicationSessionObserverDelegate) {
        self.applicationDelegate = delegate
        super.init()
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

    }

    deinit {
        notificationCenter.removeObserver(self)
    }
    
    @objc func didBecomeActive() {
        applicationDelegate?.didBecomeActive()
    }
    
    @objc func willResignActive() {
        applicationDelegate?.willResignActive()
    }
    
    @objc func didEnterBackground() {
        applicationDelegate?.didEnterBackground()
    }
}
