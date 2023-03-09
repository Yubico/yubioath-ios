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
import UIKit

private let defaultTextColor = UIColor.label
private let defaultDisabledTextColor = UIColor.tertiaryLabel

class YubiMenu: UIView {

    let actions: [MenuAction]

    init(actions: [MenuAction]) {
        self.actions = actions
        super.init(frame: CGRect.zero)
        self.layer.cornerRadius = 10
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.2
        self.layer.shadowOffset = CGSize.zero
        self.layer.shadowRadius = 25
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = UIColor(named: "MenuDivider")
        let stack = UIStackView()
        stack.axis = .vertical
        
        stack.spacing = 1
        stack.layer.cornerRadius = 10
        stack.clipsToBounds = true
        
        var lastSelectedRow: UIStackView?

        actions.forEach { action in
            let label = UILabel()
            label.font = .preferredFont(forTextStyle: .body)
            if action.style == .destructive {
                label.textColor = .systemRed
            }
            label.text = action.title
            let image = action.image?.withRenderingMode(.alwaysTemplate).withConfiguration(UIImage.SymbolConfiguration(pointSize: label.font.pointSize))
            let imageView = UIImageView(image: image)
            imageView.tintColor = label.textColor
            imageView.contentMode = .center
            let row = UIStackView(arrangedSubviews: [label, imageView])
            row.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
            row.isLayoutMarginsRelativeArrangement = true
            row.backgroundColor = UIColor(named: "MenuBackground")
            stack.addArrangedSubview(row)
            NSLayoutConstraint.activate([imageView.widthAnchor.constraint(equalToConstant: 20)])
        
            action.enabledCallback = { isEnabled in
                label.textColor = isEnabled ? defaultTextColor : defaultDisabledTextColor
                imageView.tintColor = isEnabled ? defaultTextColor : defaultDisabledTextColor
            }
        }
        self.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            stack.leftAnchor.constraint(equalTo: self.leftAnchor),
            stack.rightAnchor.constraint(equalTo: self.rightAnchor),
            self.widthAnchor.constraint(equalToConstant: 250)
            
        ])
        
        
        let gestureRecognizer = MenuGestureRecognizer { recognizer in
            guard let recognizer = recognizer as? MenuGestureRecognizer else { return }
            switch recognizer.buttonState {
            case .touchDown:
                if actions[recognizer.index].isEnabled == true {
                    lastSelectedRow = recognizer.row
                    lastSelectedRow?.backgroundColor = UIColor(named: "MenuSelectedBackground")
                }
            case .touchUpInside:
                if actions[recognizer.index].isEnabled {
                    recognizer.row?.backgroundColor = UIColor(named: "MenuBackground")
                    lastSelectedRow = nil
                    actions[recognizer.index].action()
                }
            case .dragInside:
                if actions[recognizer.index].isEnabled && recognizer.row != lastSelectedRow {
                    lastSelectedRow?.backgroundColor = UIColor(named: "MenuBackground")
                    lastSelectedRow = recognizer.row
                    lastSelectedRow?.backgroundColor = UIColor(named: "MenuSelectedBackground")
                    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                        self.transform = .identity
                    }
                }
            case .cancelled:
                lastSelectedRow?.backgroundColor = UIColor(named: "MenuBackground")
                lastSelectedRow = nil
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                    self.transform = .identity
                }
            case .dragOutside:
                lastSelectedRow?.backgroundColor = UIColor(named: "MenuBackground")
                lastSelectedRow = nil
                print(recognizer.distanceFromMenu)
                
                let scale = (200 - min(50, recognizer.distanceFromMenu / 4)) / 200
                
                UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
                    self.transform = CGAffineTransform(scaleX: scale, y: scale)
                }
                recognizer.row?.backgroundColor = UIColor(named: "MenuBackground")
            }
        }
        
        self.addGestureRecognizer(gestureRecognizer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class MenuAction {
    
    public enum Style {
        case `default`
        case destructive
    }
    
    init(title: String, image: UIImage?, action: @escaping () -> Void, style: Style = .default) {
        self.title = title
        self.image = image
        self.action = action
        self.style = style
        self.isEnabled = true
    }
    
    var isEnabled: Bool {
        willSet {
            guard let enabledCallback = enabledCallback else { return }
            enabledCallback(newValue)
        }
    }
    
    fileprivate var enabledCallback: ((Bool) -> Void)?
    let title: String
    let image: UIImage?
    let action: () -> Void
    let style: Style
}
