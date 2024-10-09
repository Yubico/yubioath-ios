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
import SwiftUI

struct NFCSettingsView: UIViewControllerRepresentable {
    typealias UIViewControllerType = NFCSettingsController
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> NFCSettingsController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "YubiKeyApplicationSettings") as? NFCSettingsController else { fatalError() }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: NFCSettingsController, context: Context) { }
}

class NFCSettingsController: UITableViewController {
    
    private var viewModel = ApplicationSettingsViewModel()

    @IBOutlet weak var bypassTouchSwitch: UISwitch!
    @IBOutlet weak var nfcOnAppLaunchSwitch: UISwitch!
    @IBOutlet weak var nfcOnOTPLaunchSwitch: UISwitch!
    @IBOutlet weak var copyOTPSwitch: UISwitch!
    
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
        print("deinit NFCSettingsController")
    }
}
