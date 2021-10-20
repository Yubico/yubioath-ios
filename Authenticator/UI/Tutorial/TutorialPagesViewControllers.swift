//
//  TutorialPagesViewControllers.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/12/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class TutorialOpenUrlViewController: UIViewController {
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

class TutorialWelcomeViewController: TutorialOpenUrlViewController {
    static let identifier = "FreWelcomeViewController"
}

class Tutorial5CiViewController: UIViewController {
    static let identifier = "Fre5CiViewController"
}

class TutorialNFCViewController: UIViewController {
    static let identifier = "FreNfcViewController"
}

class TutorialQRViewController: UIViewController {
    static let identifier = "FreQRViewController"
}
