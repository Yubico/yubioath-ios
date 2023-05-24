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

import UIKit

class NFCSettingsController: UITableViewController {
    
    private var viewModel = ApplicationSettingsViewModel()

    @IBOutlet weak var bypassTouchSwitch: UISwitch!
    @IBOutlet weak var nfcOnAppLaunchSwitch: UISwitch!
    @IBOutlet weak var nfcOnOTPLaunchSwitch: UISwitch!
    @IBOutlet weak var copyOTPSwitch: UISwitch!

    func dismiss() {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func changeBypassTouchSetting(_ sender: UISwitch) {
        viewModel.isBypassTouchEnabled = sender.isOn
    }
    
    @IBAction func changeNFCOnAppLaunchSetting(_ sender: UISwitch) {
        viewModel.isNFCOnAppLaunchEnabled = sender.isOn
    }
    
    @IBAction func changeNFCOnOTPLaunchSetting(_ sender: UISwitch) {
        viewModel.isNFCOnOTPLaunchEnabled = sender.isOn
    }
    
    @IBAction func changeCopyOTPSetting(_ sender: UISwitch) {
        viewModel.isCopyOTPEnabled = sender.isOn
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bypassTouchSwitch.isOn = viewModel.isBypassTouchEnabled
        nfcOnAppLaunchSwitch.isOn = viewModel.isNFCOnAppLaunchEnabled
        nfcOnOTPLaunchSwitch.isOn = viewModel.isNFCOnOTPLaunchEnabled
        copyOTPSwitch.isOn = viewModel.isCopyOTPEnabled
     }
    
    deinit {
        print("deinit ApplicationSettingsController")
    }
}
