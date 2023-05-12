/*
 * Copyright (C) 2023 Yubico.
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
import Combine

class OTPTableViewCell: UITableViewCell {
    
    var viewModel: OATHViewModel!
    
    @IBOutlet weak var otp: UILabel!
    @IBOutlet weak var icon: UIImageView!
    
    override open func layoutSubviews() {
        super.layoutSubviews()
        // Wait for the next runloop before setting the cornerRadius
        DispatchQueue.main.async {
            self.icon.layer.cornerRadius = self.icon.bounds.height / 2.0
        }
    }
    
}
