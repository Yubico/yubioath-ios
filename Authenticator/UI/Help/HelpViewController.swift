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

class HelpViewController: UITableViewController {

    // MARK: - Table view data source
    
    @IBOutlet weak var versionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        versionLabel.text = "\(UIApplication.appVersion) (build \(UIApplication.appBuildNumber))"
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch (indexPath.section, indexPath.row) {
        case (0, 1):
            let whatsNewController = VersionHistoryViewController()
            self.present(whatsNewController, animated: true)
        case (0, 2):
            if let url = URL(string: "https://www.yubico.com/support/terms-conditions/yubico-license-agreement/") {
                UIApplication.shared.open(url)
            }
        case (0, 3):
            if let url = URL(string: "https://www.yubico.com/support/terms-conditions/privacy-notice/") {
                UIApplication.shared.open(url)
            }
        case (0, 4):
            let licensingViewController = LicensingViewController()
            self.navigationController?.pushViewController(licensingViewController, animated: true)
        case (1, 0):
            if let url = URL(string: "https://support.yubico.com/") {
                UIApplication.shared.open(url)
            }
        case (1, 1):
            if let url = URL(string: "https://support.yubico.com/support/tickets/new") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
