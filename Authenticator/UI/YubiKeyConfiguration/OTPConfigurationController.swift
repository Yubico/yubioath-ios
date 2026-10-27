/*
 * Copyright (C) 2022 Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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
import OSLog
import YubiKit

struct OTPConfigurationView: UIViewControllerRepresentable {
    typealias UIViewControllerType = OTPConfigurationController
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> OTPConfigurationController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "YubiKeyConfigurationConroller") as? OTPConfigurationController else { fatalError() }
        vc.coordinator = context.coordinator
        vc.coordinator?.dismissHandler = { dismiss() }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: OTPConfigurationController, context: Context) {
        // Updates the state of the specified view controller with new information from SwiftUI.
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        
        var dismissHandler: (() -> Void)?
        
        func dismissView() {
            dismissHandler?()
        }
    }
}

/* This class is for showing YubiKey MGMT configuration over OTP whether it's on or off.
 Users can customize the configuration by switching tagSwitch and saving the change.
 For YubiKey NFC it is showing website NFC tag notification on YubiKey tap against the device.
 For YubiKey 5Ci it is printing key string in text fields on YubiKey touch.
 */
class OTPConfigurationController: UITableViewController {
    
    var coordinator: OTPConfigurationView.Coordinator?
    
    public var viewModel = ManagementViewModel()
    var configuration: ManagementViewModel.OTPConfiguration? = nil

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var tagSwitch: UISwitch!
    
    func dismiss() {
        coordinator?.dismissView()
    }
    
    @IBAction func changeSetting(_ sender: UISwitch) {
        let enabled = sender.isOn
        Task {
            do {
                try await viewModel.setOTPEnabled(enabled: enabled)
            } catch {
                let alert = UIAlertController(title: String(localized: "Error writing configuration", comment: "OTP settings error alert title"), message: LocalizedErrorWrapper(error: error).localizedDescription, preferredStyle: .alert)
                let action = UIAlertAction(title: String(localized: "Ok"), style: .default) { _ in
                    self.dismiss()
                }
                alert.addAction(action)
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            do {
                let configuration = try await viewModel.isOTPEnabled()
                self.configuration = configuration
                self.tagSwitch.isOn = configuration.isEnabled
                self.tagSwitch.isEnabled = configuration.isSupported && !configuration.isConfigurationLocked
                if self.tagSwitch.isEnabled {
                    if configuration.transport == .usb {
                        self.descriptionLabel.text = String(localized: "If enabled, the YubiKey will output a One-Time Password when touched. Since the YubiKey is detected as a keyboard the built in keyboard in iOS will be disabled.")
                    }
                    if configuration.transport == .nfc {
                        self.descriptionLabel.text = String(localized: "If enabled, scanning the YubiKey will display a notification. Tapping the notification will reveal the One-Time Password.")
                    }
                } else {
                    self.descriptionLabel.text = String(localized: "This setting is not supported on your YubiKey.")
                }
                self.descriptionLabel.sizeToFit()
            } catch {
                let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                let action = UIAlertAction(title: "Ok", style: .default) { _ in
                    self.dismiss()
                }
                alert.addAction(action)
                self.dismiss()
            }
        }
        
        viewModel.didDisconnect { [weak self] isNFC, error in
            if error == nil && isNFC { return }

            // Handle disconnect caused by key being removed, or by the user cancelling NFC, NFC timing out
            // or the NFC sheet being closed with an error message
            if error == nil || isNFC {
                self?.dismiss()
                return
            }
            // Handle error
            let alert = UIAlertController(title: error.map { LocalizedErrorWrapper(error: $0).localizedDescription } ?? String(localized: "Unknown error"), message: nil, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) { _ in
                self?.dismiss()
            }
            alert.addAction(action)
            self?.present(alert, animated: true, completion: nil)
        }
    }

    deinit {
        Logger.allocation.debug("OTPConfigurationController: deinit")
    }
}
