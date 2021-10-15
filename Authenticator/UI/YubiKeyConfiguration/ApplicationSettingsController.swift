//
//  ApplicationSettings.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-10-13.
//  Copyright © 2021 Yubico. All rights reserved.
//

import UIKit

class ApplicationSettingsController: UITableViewController {
    
    private var viewModel = ApplicationSettingsViewModel()

    @IBOutlet weak var bypassTouchSwitch: UISwitch!
    @IBOutlet weak var nfcOnAppLaunchSwitch: UISwitch!

    func dismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func changeBypassTouchSetting(_ sender: UISwitch) {
        viewModel.isBypassTouchEnabled = sender.isOn
    }
    
    @IBAction func changeNFCOnAppLaunchSetting(_ sender: UISwitch) {
        viewModel.isNFCOnAppLaunchEnabled = sender.isOn
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bypassTouchSwitch.isOn = viewModel.isBypassTouchEnabled
        nfcOnAppLaunchSwitch.isOn = viewModel.isNFCOnAppLaunchEnabled
     }
    
    deinit {
        print("deinit ApplicationSettingsController")
    }
}
