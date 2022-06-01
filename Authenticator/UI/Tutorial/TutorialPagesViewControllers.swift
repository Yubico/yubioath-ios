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
