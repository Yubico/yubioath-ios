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
import OSLog

struct OTPConfigurationView: UIViewControllerRepresentable {
    typealias UIViewControllerType = OTPConfigurationController
    @Environment(\.dismiss) private var dismiss
    @State var coordinator: OTPConfigurationView.Coordinator?
    
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
        let coordinator = Coordinator()
        DispatchQueue.main.async {
            self.coordinator = coordinator
        }
        return coordinator
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
        viewModel.setOTPEnabled(enabled: sender.isOn) { error in
            DispatchQueue.main.async {
                guard error == nil else {
                    let alert = UIAlertController(title: String(localized: "Error writing configuration", comment: "OTP settings error alert title"), message: error?.localizedDescription, preferredStyle: .alert)
                    let action = UIAlertAction(title: String(localized: "Ok"), style: .default) { _ in
                        self.dismiss()
                    }
                    alert.addAction(action)
                    DispatchQueue.main.async {
                        self.present(alert, animated: true, completion: nil)
                    }
                    return
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewModel.isOTPEnabled { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let configuration):
                    self.configuration = configuration
                    self.tagSwitch.isOn = configuration.isEnabled
                    self.tagSwitch.isEnabled = configuration.isSupported && !configuration.isConfigurationLocked
                    if self.tagSwitch.isEnabled {
                        if configuration.transport == .USB {
                            self.descriptionLabel.text = "Turn on/off output of OTP codes when touching the YubiKey."
                        }
                        if configuration.transport == .NFC {
                            self.descriptionLabel.text = "Turn on/off opening Safari to copy your OTP when scanning the NFC YubiKey."
                        }
                    } else {
                        self.descriptionLabel.text = "This setting is not supported on your YubiKey."
                    }
                    self.descriptionLabel.sizeToFit()
                case .failure(let error):
                    let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
                    let action = UIAlertAction(title: "Ok", style: .default) { _ in
                        self.dismiss()
                    }
                    alert.addAction(action)
                    self.dismiss()
                }
            }
        }
        
        viewModel.didDisconnect { [weak self] connection, error in
            if error == nil && (connection as? YKFNFCConnection) != nil { return }
            
            // Handle disconnect caused by key being removed
            if error == nil {
                DispatchQueue.main.async {
                    self?.dismiss()
                }
                return
            }
            // Handle disconnect caused by user cancelling nfc or nfc timeout
            if let nfcError = error as? NSError {
                if nfcError.domain == NFCErrorDomain && (nfcError.code == 200 || nfcError.code == 201) {
                    DispatchQueue.main.async {
                        self?.dismiss()
                    }
                    return
                }
            }
            // Handle error
            let alert = UIAlertController(title: error?.localizedDescription ?? String(localized: "Unknown error"), message: nil, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) { _ in
                self?.dismiss()
            }
            alert.addAction(action)
            DispatchQueue.main.async {
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }

    deinit {
        Logger.allocation.debug("OTPConfigurationController: deinit")
    }
}
