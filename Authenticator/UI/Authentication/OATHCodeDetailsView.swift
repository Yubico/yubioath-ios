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

class OATHCodeDetailsView: UIVisualEffectView {
    
    weak var parentViewController: UIViewController?
    let viewModel: OATHViewModel
    
    let containerHeightConstraint: NSLayoutConstraint
    var containerTopConstraint: NSLayoutConstraint?
    var containerCenterYConstraint: NSLayoutConstraint?
    var containerLeadingConstraint: NSLayoutConstraint?
    var containerTrailingConstraint: NSLayoutConstraint?
    
    var codeContainerRightConstraint: NSLayoutConstraint?
    var codeContainerBottomConstraint: NSLayoutConstraint?
    
    var textStackTopConstraint: NSLayoutConstraint?
    var textStackBottomConstraint: NSLayoutConstraint?
    var textStackLeftConstraint: NSLayoutConstraint?
    
    private var timerObservation: NSKeyValueObservation?
    private var otpObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var accountObservation: NSKeyValueObservation?
    private var issuerObservation: NSKeyValueObservation?
    
    var container: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(named: "DetailsBackground")
        view.alpha = 1
        view.layer.cornerRadius = 15
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 25
        view.alpha = 0
        return view
    }()
    
    var codeBackground: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(named: "DetailsCodeBackground")
        view.alpha = 0
        view.layer.cornerRadius = 10
        return view
    }()
    lazy var codeContainer: UIView = {
        let stack = UIStackView(arrangedSubviews: [actionIcon, progress, codeLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.spacing = 5
        return stack
    }()
    var codeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 23, weight: .regular)
        return label
    }()
    let progress: PieProgressBar = {
        let progress = PieProgressBar()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.tintColor = .secondaryLabel
        NSLayoutConstraint.activate([progress.widthAnchor.constraint(equalToConstant: 20),
                                     progress.heightAnchor.constraint(equalToConstant: 20)])
        return progress
    }()
    var actionIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([imageView.widthAnchor.constraint(equalToConstant: 20),
                                     imageView.heightAnchor.constraint(equalToConstant: 20)])
        imageView.tintColor = .secondaryLabel
        return imageView
    }()
    
    lazy var textStack: UIStackView = {
        let textStack = UIStackView()
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.distribution = .fillEqually
        textStack.spacing = 2
        textStack.addArrangedSubview(UIView())
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        textStack.addArrangedSubview(UIView())
        return textStack
    }()
    var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        label.textColor = .label
        return label
    }()
    var subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        return label
    }()
    
    @objc dynamic let credential: Credential
    
    var menu = YubiMenu(actions: [])
    var copyMenuAction: MenuAction?
    var calculateMenuAction: MenuAction?
    
    init(credential: Credential, viewModel: OATHViewModel, parentViewController: UIViewController) {
        self.parentViewController = parentViewController
        self.credential = credential
        self.viewModel = viewModel
        progress.setProgress(to: !credential.code.isEmpty ? credential.remainingTime / Double(credential.period) : 0)
        containerHeightConstraint = container.heightAnchor.constraint(equalToConstant: 88)
        super.init(effect: nil)
        
        calculateMenuAction = credential.type == .HOTP || credential.requiresTouch || !viewModel.keyPluggedIn ? MenuAction(title: "Calculate", image: UIImage(systemName: "arrow.clockwise"), action: {
            viewModel.calculate(credential: credential)
            print("calculate")
        }) : nil
        
        copyMenuAction = {
            MenuAction(title: "Copy", image: UIImage(systemName: "square.and.arrow.up"),
                       action: {
                viewModel.copyToClipboard(value: credential.code)
            })
        }()
        
        let favoriteAction: MenuAction = {
            if viewModel.isPinned(credential: credential) {
                return MenuAction(title: "Unpin",
                                  image: UIImage(systemName: "pin.slash"),
                                  action: { [weak self] in
                    viewModel.unPin(credential: credential)
                    self?.dismiss()
                })
            } else {
                return MenuAction(title: "Pin",
                                  image: UIImage(systemName: "pin"),
                                  action: { [weak self] in
                    viewModel.pin(credential: credential)
                    self?.dismiss()
                })
            }
        }()
        
        let editAction: MenuAction? = {
            if credential.keyVersion >= YKFVersion(bytes: 5, minor: 3, micro: 0) {
                let action = {
                    let storyboard = UIStoryboard(name: "EditCredential", bundle: nil)
                    guard let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController,
                          let editController = navigationController.children.first as? EditCredentialController
                    else { return }
//                    editController.credential = credential
//                    editController.viewModel = viewModel
                    parentViewController.present(navigationController, animated: true)
                }
                return MenuAction(title: "Rename", image: UIImage(systemName: "square.and.pencil"), action: action)
            } else {
                return nil
            }}()
        
        let deleteAction: MenuAction = {
            MenuAction(title: "Delete",
                       image: UIImage(systemName: "trash"),
                       action: {
                parentViewController.showWarning(title: "Delete \"\(credential.formattedName)\"?",
                                                 message: "This will permanently delete the credential from the YubiKey, and your ability to generate codes for it",
                                                 okButtonTitle: "Delete") { [weak self] () -> Void in
                    viewModel.deleteCredential(credential: credential)
                    self?.dismiss()
                }
            },
                       style: .destructive)
        }()
        
        menu = YubiMenu(actions: [calculateMenuAction,
                              copyMenuAction,
                              favoriteAction,
                              editAction,
                              deleteAction].compactMap{ $0 })
        menu.alpha = 0
        menu.translatesAutoresizingMaskIntoConstraints = false
        menu.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        menu.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
        
        contentView.addSubview(container)
        contentView.addSubview(menu)
        
        containerTopConstraint = container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0)
        containerCenterYConstraint = container.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -70)
        containerCenterYConstraint?.priority = .defaultLow
        
        container.addSubview(codeBackground)
        container.addSubview(codeContainer)
        codeContainerBottomConstraint = codeContainer.centerYAnchor.constraint(equalTo: codeBackground.centerYAnchor, constant: 0)
        codeContainerRightConstraint = codeContainer.rightAnchor.constraint(equalTo: container.rightAnchor, constant: 0)
        containerLeadingConstraint = container.leftAnchor.constraint(equalTo: leftAnchor, constant: 0)
        containerTrailingConstraint = container.rightAnchor.constraint(equalTo: rightAnchor, constant: 0)
        
        container.addSubview(textStack)
        textStackTopConstraint = textStack.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor)
        textStackBottomConstraint = textStack.bottomAnchor.constraint(equalTo: codeBackground.topAnchor, constant: 70)
        textStackLeftConstraint = textStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 65)
        textStackLeftConstraint?.priority = .required
        let textStackLeadingConstraint = textStack.leadingAnchor.constraint(equalTo: codeBackground.leadingAnchor)
        textStackLeadingConstraint.priority = .defaultHigh
        let textStackTrailingConstraint = textStack.trailingAnchor.constraint(equalTo: codeBackground.trailingAnchor)
        textStackTrailingConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([textStackLeadingConstraint,
                                     textStackTrailingConstraint,
                                     textStackLeftConstraint,
                                     textStackTopConstraint,
                                     textStackBottomConstraint].compactMap { $0 })
        
        
        NSLayoutConstraint.activate([containerTopConstraint,
                                     containerCenterYConstraint,
                                     containerLeadingConstraint,
                                     containerTrailingConstraint,
                                     containerHeightConstraint,
                                     codeContainerBottomConstraint,
                                     codeContainerRightConstraint,
                                     menu.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0),
                                     menu.centerYAnchor.constraint(equalTo: container.bottomAnchor, constant: 15),
                                     codeBackground.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
                                     codeBackground.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
                                     codeBackground.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -15),
                                     codeBackground.heightAnchor.constraint(equalToConstant: 57)].compactMap { $0 })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func present(from: CGPoint) {
        setupModelObservation()
        
        if let keyWindow = UIApplication.shared.connectedScenes
            .filter({$0.activationState == .foregroundActive})
            .map({$0 as? UIWindowScene})
            .compactMap({$0})
            .first?.windows
            .filter({$0.isKeyWindow}).first {
            self.frame = keyWindow.bounds
            keyWindow.addSubview(self)
        }
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
        contentView.addGestureRecognizer(tap)
        
        containerTopConstraint?.constant = from.y + 50
        
        updateMenuItems()
        refreshCode()
        refreshName()
        
        if credential.type == .HOTP {
            let size = UIFontMetrics.default.scaledValue(for: 17)
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "arrow.clockwise.circle.fill", withConfiguration: config)
        } else {
            let size = UIFontMetrics.default.scaledValue(for: 15)
            let config = UIImage.SymbolConfiguration(pointSize: size, weight: .medium, scale: .medium)
            actionIcon.image = UIImage(systemName: "hand.tap.fill", withConfiguration: config)
        }
        
        actionIcon.isHidden = !credential.showActionIcon
        progress.isHidden = !credential.showProgress
        codeLabel.textColor = credential.codeColor
        progress.alpha = 1
        
        layoutIfNeeded()
        progress.setProgress(to: credential.remainingTime / Double(credential.period))
        codeContainer.applyTransform(withScale: 0.8, anchorPoint: CGPoint(x: 0, y: 0.5))
        
        UIView.animate(withDuration: 0.1) {
            self.container.alpha = 1
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            
            self.codeContainerBottomConstraint?.constant = 0
            self.codeContainer.applyTransform(withScale: 1, anchorPoint: CGPoint(x: 0, y: 0.5))
            // The anchor point is on the middle left side so we have to calculate the margin manually
            self.codeContainerRightConstraint?.constant = -(self.container.frame.width - 60 - self.codeContainer.frame.width) / 2
            self.codeBackground.alpha = 1
            
            self.textStack.alignment = .center
            self.textStackBottomConstraint?.constant = 0
            self.textStackTopConstraint?.constant = 0
            self.textStackLeftConstraint?.priority = .defaultLow
            
            self.containerLeadingConstraint?.constant = 30
            self.containerTrailingConstraint?.constant = -30
            self.containerTopConstraint?.priority = .defaultLow
            self.containerCenterYConstraint?.priority = .required
            self.containerHeightConstraint.constant = 160
            self.layoutIfNeeded()
        }
        
        UIView.animate(withDuration: 0.1, delay: 0.1, options: .curveEaseInOut) {
            self.menu.transform = .identity
            self.menu.alpha = 1
        }
    }
    
    @objc func dismiss() {
        UIView.animate(withDuration: 0.1, delay: 0.15, options: .curveEaseOut) {
            self.container.alpha = 0
            self.codeBackground.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.effect = nil
            self.textStack.alignment = .leading
            
            self.containerCenterYConstraint?.priority = .defaultLow
            self.containerLeadingConstraint?.constant = 0
            self.containerTrailingConstraint?.constant = 0
            self.containerHeightConstraint.constant = 88
            
            self.codeContainer.applyTransform(withScale: 0.8, anchorPoint: CGPoint(x: 0, y: 0.5))
            self.codeContainerBottomConstraint?.constant = 6
            self.codeContainerRightConstraint?.constant = 0
            
            self.textStackBottomConstraint?.constant = 70
            self.textStackLeftConstraint?.priority = .required
            
            self.menu.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            self.menu.alpha = 0
            self.layoutIfNeeded()
        }
    }
    
    private func setupModelObservation() {
        if credential.type == .TOTP {
            timerObservation = observe(\.credential.remainingTime, options: [], changeHandler: { (object, change) in
                DispatchQueue.main.async { [weak self] in
                    self?.refreshProgress()
                }
            })
        } else {
            timerObservation = observe(\.credential.activeTime, options: [], changeHandler: { (object, change) in
                DispatchQueue.main.async { [weak self] in
                    self?.refreshProgress()
                }
            })
        }
        otpObservation = observe(\.credential.code, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshCode()
            }
        })
        progressObservation = observe(\.credential.state, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshProgress()
            }
        })
        
        accountObservation = observe(\.credential.account, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshName()
            }
        })
        issuerObservation = observe(\.credential.issuer, options: [], changeHandler: { (object, change) in
            DispatchQueue.main.async { [weak self] in
                self?.refreshName()
            }
        })
    }
    
    func refreshProgress() {
        updateMenuItems()
        
        if credential.type == .TOTP {
            if credential.remainingTime > 0 {
                progress.setProgress(to: credential.remainingTime / Double(credential.period))
            } else {
                // keeping old value of code on screen even if it's expired already
                progress.setProgress(to: Double(0.0))
            }
        }
        
        actionIcon.isHidden = !credential.showActionIcon
        progress.isHidden = !credential.showProgress
        codeLabel.textColor = credential.codeColor
    }
    
    func refreshName() {
        if let issuer = credential.issuer, !issuer.isEmpty {
            titleLabel.text = issuer
            subtitleLabel.text = credential.account
            subtitleLabel.isHidden = false
        } else {
            titleLabel.text = credential.account
            subtitleLabel.text = nil
            subtitleLabel.isHidden = true
        }
    }
    
    func refreshCode() {
        let otp = credential.formattedCode
        codeLabel.text = otp
        codeLabel.textColor = credential.codeColor
    }
    
    func updateMenuItems() {
        copyMenuAction?.isEnabled = (credential.type == .HOTP  && credential.code != "") || (credential.type == .TOTP && !credential.requiresRefresh)
        calculateMenuAction?.isEnabled = credential.type == .HOTP || credential.requiresRefresh
    }
}

extension UIView {
    func applyTransform(withScale scale: CGFloat, anchorPoint: CGPoint) {
        layer.anchorPoint = anchorPoint
        let scale = scale != 0 ? scale : CGFloat.leastNonzeroMagnitude
        let xPadding = 1 / scale * (anchorPoint.x - 0.5) * bounds.width
        let yPadding = 1 / scale * (anchorPoint.y - 0.5) * bounds.height
        transform = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xPadding, y: yPadding)
    }
}
