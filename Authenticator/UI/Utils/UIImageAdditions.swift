//
//  UIImageAdditions.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 12/13/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

extension UIImage {
    /// Returns a system image on iOS 13, otherwise returns an image from the Bundle provided.
    convenience init?(nameOrSystemName: String, in bundle: Bundle? = Bundle.main, compatibleWith traitCollection: UITraitCollection? = nil) {
        if #available(iOS 13, *) {
            self.init(systemName: nameOrSystemName, compatibleWith: traitCollection)
        } else {
            self.init(named: nameOrSystemName, in: bundle, compatibleWith: traitCollection)
        }
    }
}
