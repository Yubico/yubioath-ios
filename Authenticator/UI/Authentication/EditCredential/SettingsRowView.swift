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
        valueLabel.textColor = .systemGray
        self.backgroundColor = .clear
        self.titleLabel.font = .preferredFont(forTextStyle: .body)
        self.valueLabel.font = .preferredFont(forTextStyle: .body)
        self.valueLabel.adjustsFontSizeToFitWidth = true
        self.valueLabel.allowsDefaultTighteningForTruncation = true
        self.valueLabel.minimumScaleFactor = 0.5
        self.valueLabel.lineBreakMode = .byTruncatingTail
        self.titleLabel.textColor = .label
        self.titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.valueLabel.textColor = .secondaryLabel
        self.addSubview(titleLabel)
        self.addSubview(valueLabel)
        self.addConstraints([self.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor, constant: 0),
                             self.topAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -10),
                             self.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
                             titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -10),
                             self.trailingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 10),
                             self.topAnchor.constraint(equalTo: valueLabel.topAnchor, constant: -10),
                             self.bottomAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 10),
                            ])
    }
}
