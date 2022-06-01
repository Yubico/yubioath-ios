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
    
    static var background: UIColor {
        get {
            if #available(iOS 13.0, *) {
                return UIColor.systemBackground
            } else {
                return UIColor.white
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
    
    static var yubiGreen: UIColor {
        get {
            guard let color = UIColor(named: "YubiGreen") else {
                return UIColor.gray
            }
            return color
        }
    }
    
    static let colorSetForAccountIcons = [UIColor(named: "Color1"),
                                          UIColor(named: "Color2"),
                                          UIColor(named: "Color3"),
                                          UIColor(named: "Color4"),
                                          UIColor(named: "Color5"),
                                          UIColor(named: "Color6"),
                                          UIColor(named: "Color7"),
                                          UIColor(named: "Color8"),
                                          UIColor(named: "Color9"),
                                          UIColor(named: "Color10"),
                                          UIColor(named: "Color11"),
                                          UIColor(named: "Color12"),
                                          UIColor(named: "Color13"),
                                          UIColor(named: "Color14"),
                                          UIColor(named: "Color15"),
                                          UIColor(named: "Color16")]
}
