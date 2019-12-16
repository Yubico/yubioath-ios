//
//  UIImageAdditions.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 12/13/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UIImage {
    
    static var star: UIImage {
        get {
            if #available(iOS 13.0, *) {
                return UIImage(systemName: "star") ?? UIImage()
            } else {
                return UIImage(named: "Star") ?? UIImage()
            }
        }
    }
    
    static var starFilled: UIImage {
        get {
            if #available(iOS 13.0, *) {
                return UIImage(systemName: "star.fill") ?? UIImage()
            } else {
                return UIImage(named: "StarFilled") ?? UIImage()
            }
        }
    }
    
    static var trash: UIImage {
        get {
            if #available(iOS 13.0, *) {
                return UIImage(systemName: "trash") ?? UIImage()
            } else {
                return UIImage(named: "Delete") ?? UIImage()
            }
        }
    }
}
