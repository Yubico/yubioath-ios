//
//  SearchBar.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-10-08.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import Combine

class SearchBar: UIView {
    
    var delegate: SearchBarDelegate?
    
    var isVisible: Bool = false {
        didSet {
            let window = UIApplication.shared.windows[0]
            let topPadding = window.safeAreaInsets.top
            if isVisible {
                let _ = becomeFirstResponder()
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                    self.frame.origin.y = topPadding
                }
            } else {
                _ = resignFirstResponder()
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                    self.frame.origin.y = -self.frame.size.height
                }
            }
        }
    }
    
    private var cancellable: Cancellable?
    
    private let textField: UITextField = {
        let textField = UITextField()
        let configuration = UIImage.SymbolConfiguration(pointSize: 20)
        let image = UIImage(systemName: "magnifyingglass")?.withConfiguration(configuration)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .secondaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let imageContainer = UIView()
        imageContainer.addSubview(imageView)
        NSLayoutConstraint.activate([imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: 10),
                                     imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -10),
                                     imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
                                     imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor)])
        textField.leftViewMode = .always
        textField.leftView = imageContainer
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.backgroundColor = UIColor(named: "SearchBackground")
        textField.layer.cornerRadius = 8
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.returnKeyType = .search
        textField.adjustsFontForContentSizeCategory = true
        textField.font = .preferredFont(forTextStyle: .body)
        textField.attributedPlaceholder = NSAttributedString(string: "Search", attributes: [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel])
        return textField
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Cancel", for: .normal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setTitleColor(.yubiBlue, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()
    
    init() {
        super.init(frame: .zero)
        textField.delegate = self
        self.addSubview(textField)
        self.addSubview(cancelButton)
        self.backgroundColor = UIColor(named: "SearchBarBackground")
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            textField.topAnchor.constraint(equalTo: self.topAnchor, constant: 5),
            textField.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -5),
            cancelButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor, constant: 10),
            cancelButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10)
        ])
        
        cancellable = cancelButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.textField.text = ""
            self?.textField.resignFirstResponder()
            self?.isVisible = false
            self?.delegate?.searchBarDidCancel()
        }
        
        textField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        delegate?.searchBarDidChangeText(textField.text ?? "")
    }
    
    override func resignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }
    
    override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SearchBar: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

protocol SearchBarDelegate {
    func searchBarDidChangeText(_ text: String)
    func searchBarDidCancel()
}
