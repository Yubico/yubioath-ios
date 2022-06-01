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
import QuartzCore
import Combine

class VersionHistoryViewController: UIViewController {
    
    private var cancellable: Cancellable?
    private var closeButton = UIButton()
    private var titleLabel = UILabel()
    var closeBlock: (() -> ())?
    
    var closeButtonText: String = "Close" {
        didSet {
            closeButton.setTitle(closeButtonText, for: .normal)
        }
    }
    
    var titleText: String = "Version history" {
        didSet {
            titleLabel.text = titleText
        }
    }
    
    static var shouldShowOnAppLaunch: Bool {
        // Wait for first application update before showing whats new on app launch
        // Go back in history until we reach the update last shown and search for changes that should be prompted
        guard let lastVersionPrompted = SettingsConfig.lastWhatsNewVersionShown else {
            SettingsConfig.lastWhatsNewVersionShown = UIApplication.appVersion
            return false
        }

        for change in changes {
            if change.version == lastVersionPrompted { return false }
            if change.shouldPromptUser { return true }
        }
        return false
    }
    
    private static var changes: [Change] = { [Change].init(withChangesFrom: "VersionHistory.plist") ?? [Change]() }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        SettingsConfig.lastWhatsNewVersionShown = UIApplication.appVersion

        view.backgroundColor = .systemBackground
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let maskView = GradientView()
        maskView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(maskView)
        
        cancellable = closeButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.dismiss(animated: true) {
                self?.closeBlock?()
            }
        }
        closeButton.backgroundColor = .yubiBlue
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.layer.cornerRadius = 15
        closeButton.setTitle(closeButtonText, for: .normal)
        closeButton.titleLabel?.font = .preferredFont(forTextStyle: .title3)
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                                     scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                                     scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                                     scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor),
                                     closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                                     closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
                                     closeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
                                     maskView.bottomAnchor.constraint(equalTo: closeButton.topAnchor),
                                     maskView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                     maskView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     maskView.heightAnchor.constraint(equalToConstant: 100)
                                    ])

        let appIcon = UIImageView(image: UIImage(named: "icon"))
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.layer.cornerRadius = 10
        appIcon.clipsToBounds = true
        scrollView.addSubview(appIcon)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = titleText
        
        titleLabel.font = .preferredFont(forTextStyle: .title1).withSymbolicTraits(.traitBold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
//        titleLabel.minimumScaleFactor = 0.5
//        titleLabel.adjustsFontSizeToFitWidth = true
        scrollView.addSubview(titleLabel)
        
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        scrollView.addSubview(stack)
        
        NSLayoutConstraint.activate([appIcon.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 60),
                                     appIcon.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
                                     appIcon.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -20),
                                     titleLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 10),
                                     titleLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -10),
                                     titleLabel.bottomAnchor.constraint(equalTo: stack.topAnchor, constant: -25),
                                     stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
                                     stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
                                     stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                                     stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
                                    ])

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.doesRelativeDateFormatting = true
        
        Self.changes.forEach { change in
            let changeHeaderStack = UIStackView()
            let versionLabel = UILabel()
            versionLabel.font = .preferredFont(forTextStyle: .body).withSymbolicTraits(.traitBold)
            versionLabel.text = change.version
            changeHeaderStack.addArrangedSubview(versionLabel)
            let dateLabel = UILabel()
            dateLabel.font = .preferredFont(forTextStyle: .body).withSymbolicTraits(.traitBold)
            dateLabel.text = dateFormatter.string(from: change.date)
            dateLabel.textAlignment = .right
            dateLabel.textColor = .secondaryText
            changeHeaderStack.addArrangedSubview(dateLabel)
            stack.addArrangedSubview(changeHeaderStack)
            stack.setCustomSpacing(5, after: changeHeaderStack)
            
            if let changeText = change.text {
                let changeLabel = UILabel()
                changeLabel.font = .preferredFont(forTextStyle: .body)
                changeLabel.text = changeText
                changeLabel.numberOfLines = 0
                changeLabel.lineBreakMode = .byWordWrapping
                stack.addArrangedSubview(changeLabel)
                stack.setCustomSpacing(5, after: changeLabel)
            }
            
            change.rows.forEach {
                let rowStack = UIStackView()
                rowStack.alignment = .top
                
                let bulletLabel = UILabel()
                bulletLabel.font = .preferredFont(forTextStyle: .body)
                bulletLabel.text = " • "

                bulletLabel.setContentHuggingPriority(.required, for: .horizontal)
                bulletLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
                rowStack.addArrangedSubview(bulletLabel)
                
                let label = UILabel()
                label.font = .preferredFont(forTextStyle: .body)
                label.text = $0
                label.numberOfLines = 0
                label.lineBreakMode = .byWordWrapping
                rowStack.addArrangedSubview(label)
                stack.addArrangedSubview(rowStack)
            }

            
            stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)

            let dividerView = UIView()
            dividerView.translatesAutoresizingMaskIntoConstraints = false
            dividerView.backgroundColor = UIColor(named: "MenuDivider")
            stack.addArrangedSubview(dividerView)
            NSLayoutConstraint.activate([dividerView.heightAnchor.constraint(equalToConstant: 1),
                                         dividerView.widthAnchor.constraint(equalTo: stack.widthAnchor)
            ])
            stack.setCustomSpacing(20, after: dividerView)
        }
        stack.setCustomSpacing(50, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(UIView())
    }
}


extension Array where Element == Change {
    init?(withChangesFrom: String) {
        guard
            let resource = withChangesFrom.split(separator: ".").first,
            let fileExtension = withChangesFrom.split(separator: ".").last,
            let url = Bundle.main.url(forResource: String(resource), withExtension: String(fileExtension)),
            let changes = NSArray(contentsOf: url) as? [[String:Any]]
        else { return nil }
        self = changes.map { Change($0) }.compactMap { $0 }
    }
}

struct Change {
    
    let shouldPromptUser: Bool
    let version: String
    let date: Date
    let text: String?
    let rows: [String]
    
    init?(_ dictionary: [String:Any]) {
        guard
            let version = dictionary["version"] as? String,
            let text = dictionary["changes"] as? String,
            let date = dictionary["date"] as? Date,
            let shouldPromptUser = dictionary["shouldPromptUser"] as? Bool
        else { return nil }
        self.version = version
        self.date = date
        self.shouldPromptUser = shouldPromptUser
        let parts = text.components(separatedBy: " - ")
        self.text = parts.first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        self.rows = parts.dropFirst().compactMap { row in
            guard !row.isEmpty else { return nil }
            return String(row).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

}


extension UIFont {
    /// Returns a new font in the same family with the given symbolic traits,
    /// or `nil` if none found in the system.
    func withSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        guard let descriptorWithTraits = fontDescriptor.withSymbolicTraits(traits)
            else { return nil }
        return UIFont(descriptor: descriptorWithTraits, size: 0)
    }
}


class GradientView: UIView {
    
    init() {
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        layer.mask = gradientLayer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        layer.mask?.frame = self.bounds
    }
}
