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
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold, scale: .medium)
        let largeBoldDoc = UIImage(systemName: symbol, withConfiguration: largeConfig)
        self.setImage(largeBoldDoc, for: .normal)
    }
   
    func setSymbol(symbol: String) {
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .bold, scale: .medium)
        let largeBoldDoc = UIImage(systemName: symbol, withConfiguration: largeConfig)
        self.setImage(largeBoldDoc, for: .normal)
    }
}
