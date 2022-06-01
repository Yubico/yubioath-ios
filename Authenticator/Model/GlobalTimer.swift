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
    
    deinit {
        self.timer = nil
        print("deinit GlobalTimer")
    }
}
