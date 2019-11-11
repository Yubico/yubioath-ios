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
}

@objc class ApplicationSessionObserver: NSObject {

private weak var applicationDelegate: ApplicationSessionObserverDelegate?
    let notificationCenter = NotificationCenter.default

    init(delegate: ApplicationSessionObserverDelegate) {
        self.applicationDelegate = delegate
        super.init()
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
    }
    
    @objc func didEnterBackground() {
        applicationDelegate?.didEnterBackground()
    }
}
