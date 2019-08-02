//
//  GlobalTimer.swift
//  YubicoAuthenticator
//
//  Created by Conrad Ciobanica on 2019-07-30.
//  Copyright © 2019 Yubico. All rights reserved.
//

@objc class GlobalTimer: NSObject {

    private var timer: Timer!
    
    // Observe to get ticks
    @objc dynamic private(set) var tick: UInt8 = 0
    
    static var shared: GlobalTimer = GlobalTimer()
    
    override init() {
        super.init()
        timer = Timer(timeInterval: 1.0, repeats: true, block: { [weak self] (timer) in
            guard let self = self else {
                return
            }

            self.tick = ~self.tick
        })
        RunLoop.main.add(timer, forMode: .common)
    }
}
