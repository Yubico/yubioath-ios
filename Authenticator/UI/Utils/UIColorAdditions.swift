//
//  UIColorAdditions.swift
//  Authenticator
//
//  Created by Irina Makhalova on 10/29/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UIColor {
    static var primaryText: UIColor {
        get {
            if #available(iOS 13.0, *) {
                return UIColor.label
            } else {
                return UIColor.darkGray
            }
        }
    }

    static var secondaryText: UIColor {
        get {
            if #available(iOS 13.0, *) {
                return UIColor.secondaryLabel
            } else {
                return UIColor.gray
            }
        }
    }
    
    static var yubiBlue: UIColor {
        get {
            guard let color = UIColor(named: "YubiBlue") else {
                return UIColor.gray
            }
            return color
        }
    }
}
