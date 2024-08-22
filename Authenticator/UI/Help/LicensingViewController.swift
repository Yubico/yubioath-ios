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

import Foundation

class LicensingViewController: UIViewController {
    
    let textView = UITextView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String(localized: "Licensing", comment: "Licensing view navigation title")
        self.view = textView
        self.navigationItem.largeTitleDisplayMode = .never
        textView.textContainerInset = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        guard let filepath = Bundle.main.path(forResource: "Licensing", ofType: "md"),
              let licensingMarkdown = try? String(contentsOfFile: filepath) else { return }
        if #available(iOS 15, *) {
            var attributedString = try! AttributedString(markdown: licensingMarkdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))
            attributedString.foregroundColor = .primaryText
            textView.attributedText = NSAttributedString(attributedString)
        } else {
            textView.text = licensingMarkdown
        }
    }
}
