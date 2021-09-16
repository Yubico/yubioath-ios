//
//  SettingsRowView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2020-05-07.
//  Copyright © 2020 Yubico. All rights reserved.
//

import UIKit

@IBDesignable class SettingsRowView: UIView {
    
    @IBInspectable var title: String? {
        get {
            return titleLabel.text
        }
        set(title) {
            titleLabel.text = title
        }
    }
    
    @IBInspectable var value: String? {
        get {
            return valueLabel.text
        }
        set(value) {
            valueLabel.text = value
        }
    }
    
    @UsesAutoLayout private var titleLabel = UILabel()
    @UsesAutoLayout private var valueLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    func setup() {
        valueLabel.textColor = .systemGray // UIColor(named: "Color18")
        self.backgroundColor = .clear
        self.titleLabel.font = .preferredFont(forTextStyle: .body)
        self.valueLabel.font = .preferredFont(forTextStyle: .body)
        self.titleLabel.textColor = .label
        self.valueLabel.textColor = .secondaryLabel
        self.addSubview(titleLabel)
        self.addSubview(valueLabel)
        self.addConstraints([self.leftAnchor.constraint(equalTo: titleLabel.leftAnchor, constant: 0),
                             self.topAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -10),
                             self.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
                             titleLabel.rightAnchor.constraint(greaterThanOrEqualTo: valueLabel.leftAnchor, constant: 10),
                             self.rightAnchor.constraint(equalTo: valueLabel.rightAnchor, constant: 10),
                             self.topAnchor.constraint(equalTo: valueLabel.topAnchor, constant: -10),
                             self.bottomAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 10)])
    }
}
