//
//  UIImageAdditions.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 12/13/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UIImage {
    
    static var star: UIImage? {
        get {
            return UIImage(named: "Star")
        }
    }
    
    static var starFilled: UIImage? {
        get {
            return UIImage(named: "StarFilled")
        }
    }
    
    static var trash: UIImage? {
        get {
            return UIImage(named: "Delete")
        }
    }
}
