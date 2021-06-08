//
//  UIApplicationExtension.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import Foundation

extension UIApplication {
    
    static var appVersion: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    static var appBuildNumber: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String
    }
}
