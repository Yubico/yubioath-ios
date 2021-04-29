// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//protocol AccessorySessionObserverDelegate: NSObjectProtocol {
//    func accessorySessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFAccessorySessionState)
//}
//
//protocol NfcSessionObserverDelegate: NSObjectProtocol {
//    func nfcSessionObserver(_ observer: KeySessionObserver, sessionStateChangedTo state: YKFNFCISO7816SessionState)
//}

/*
 The KeySessionObserver is an example on how to wrap the KVO observation of the Key Session into a separate
 class and use a delegate to notify about state changes. This example can be used to mask the KVO code when
 the target application prefers a delegate pattern.
 */
//@objc class KeySessionObserver: NSObject {
//    
//    private weak var accessoryDelegate: AccessorySessionObserverDelegate?
//    private weak var nfcDlegate: NfcSessionObserverDelegate?
//    private var queue: DispatchQueue?
//
//    private var isObservingSessionStateUpdates = false
//    private var accessorySessionObservation: NSKeyValueObservation?
//    private var nfcSessionObservation: NSKeyValueObservation?
//
//    @objc dynamic private var accessorySession: YKFAccessorySessionProtocol = YubiKitManager.shared.accessorySession
//    @objc dynamic private var nfcSession: YKFNFCSessionProtocol = YubiKitManager.shared.nfcSession
//
//    init(accessoryDelegate: AccessorySessionObserverDelegate? = nil, nfcDlegate: NfcSessionObserverDelegate? = nil, queue: DispatchQueue? = nil) {
//        self.accessoryDelegate = accessoryDelegate
//        self.nfcDlegate = nfcDlegate
//        self.queue = queue
//        super.init()
//        observeSessionState = true
//    }
//    
//    deinit {
//        observeSessionState = false
//    }
//    
//    var observeSessionState: Bool {
//        get {
//            return isObservingSessionStateUpdates
//        }
//        set {
//            guard newValue != isObservingSessionStateUpdates else {
//                return
//            }
//            isObservingSessionStateUpdates = newValue
//            
//            if isObservingSessionStateUpdates {
//                accessorySessionObservation = observe(\.accessorySession.sessionState, options: [], changeHandler: { [weak self] (object, change) in
//                    self?.accessorySessionStateDidChange()
//                })
//                
//                nfcSessionObservation = observe(\.nfcSession.iso7816SessionState, options: [], changeHandler: { [weak self] (object, change) in
//                    self?.nfcSessionStateDidChange()
//                })
//            } else {
//                accessorySessionObservation = nil
//                nfcSessionObservation = nil
//            }
//        }
//    }
//    
//    func accessorySessionStateDidChange() {
//        let queue = self.queue ?? DispatchQueue.main
//        queue.async { [weak self] in
//            guard let self = self else {
//                return
//            }
//            guard let delegate = self.accessoryDelegate else {
//                return
//            }
//            
//            let state = YubiKitManager.shared.accessorySession.sessionState
//            delegate.accessorySessionObserver(self, sessionStateChangedTo: state)
//        }
//    }
//
//    func nfcSessionStateDidChange() {
//        let queue = self.queue ?? DispatchQueue.main
//        queue.async { [weak self] in
//            guard let self = self else {
//                return
//            }
//            guard let delegate = self.nfcDlegate else {
//                return
//            }
//            
//            let state = YubiKitManager.shared.nfcSession.iso7816SessionState
//            delegate.nfcSessionObserver(self, sessionStateChangedTo: state)
//        }
//    }
//
//}
