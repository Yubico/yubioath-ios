//
//  ApplicationSessionObserver.swift
//  Authenticator
//
//  Created by Irina Makhalova on 11/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

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
