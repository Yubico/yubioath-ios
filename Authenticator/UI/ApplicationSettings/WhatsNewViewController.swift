//
//  WhatsNewViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 4/3/20.
//  Copyright © 2020 Yubico. All rights reserved.
//

import UIKit

class WhatsNewViewController: UIViewController {
    
    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        SettingsConfig.lastWhatsNewVersionShown = .whatsNewVersion
    }

}
