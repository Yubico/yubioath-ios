//
//  FreWelcomeViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/12/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {
    @IBAction func openUrl(_ sender: Any) {
        guard
            let button = sender as? UrlButton,
            let urlString = button.value(forKeyPath: "url") as? String,
            let url = URL(string: urlString)
        else { return }
        UIApplication.shared.open(url)
    }
}

class UrlButton: UIButton {
    @IBInspectable var url : String?
}

class FreWelcomeViewController: WelcomeViewController {
    static let identifier = "FreWelcomeViewController"
}

class Fre5CiViewController: UIViewController {
    static let identifier = "Fre5CiViewController"
}

class FreNfcViewController: UIViewController {
    static let identifier = "FreNfcViewController"
}

class FreQRViewController: UIViewController {
    static let identifier = "FreQRViewController"
}

class FreFavoritesViewController: UIViewController {
    static let identifier = "FreFavoritesViewController"
}
