//
//  FreWelcomeViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/12/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class FreWelcomeViewController: UIViewController {
    static let identifier = "FreWelcomeViewController"
}

class Fre5CiViewController: UIViewController {
    static let identifier = "Fre5CiViewController"
}

class FreNfcViewController: UIViewController {
    static let identifier = "FreNfcViewController"
    
    @IBOutlet weak var imageView: UIImageView! {
        didSet {
            self.imageView.layer.cornerRadius = 12.0
        }
    }
}

class FreQRViewController: UIViewController {
    static let identifier = "FreQRViewController"
}

