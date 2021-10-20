//
//  UIButton+Extensions.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-20.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation

extension UIButton {
    convenience init(withSymbol symbol: String) {
        self.init()
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .light, scale: .medium)
        let image = UIImage(systemName: symbol, withConfiguration: config)
        self.setImage(image, for: .normal)
    }
   
    func setSymbol(symbol: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .light, scale: .medium)
        let image = UIImage(systemName: symbol, withConfiguration: config)
        self.setImage(image, for: .normal)
    }
}
