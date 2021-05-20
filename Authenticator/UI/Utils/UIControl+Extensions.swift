//
//  UIControl+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Combine
import UIKit

extension UIControl {
    func addHandler(for event: UIControl.Event, block: @escaping () -> Void) -> Cancellable {
        let blockObject = BlockWrapper(block: block)
        addTarget(blockObject, action: #selector(BlockWrapper.execute), for: event)
        let cancellable = AnyCancellable {
            self.removeTarget(blockObject, action: #selector(BlockWrapper.execute), for: event)
        }
        return cancellable
    }
}

fileprivate class BlockWrapper: NSObject {
    let block: () -> Void

    init(block: @escaping () -> Void) {
        self.block = block
    }

    @objc dynamic func execute() {
        block()
    }
}
