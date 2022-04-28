//
//  OATHCodeDetailsView.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-08-27.
//  Copyright © 2021 Yubico. All rights reserved.
//

class OATHCodeDetailsView: UIVisualEffectView {
    
    weak var parentViewController: UIViewController?
    let viewModel: OATHViewModel
    
    let containerHeightConstraint: NSLayoutConstraint
    var containerTopConstraint: NSLayoutConstraint?
    var containerCenterYConstraint: NSLayoutConstraint?
    var codeLabelLeftConstraint: NSLayoutConstraint?
    var codeLabelTopConstraint: NSLayoutConstraint?
    var nameLabelLeftConstraint: NSLayoutConstraint?
    var nameLabelTopConstraint: NSLayoutConstraint?
    var nameLabelCenterConstraint: NSLayoutConstraint?

    private var timerObservation: NSKeyValueObservation?
    private var otpObservation: NSKeyValueObservation?
    private var progressObservation: NSKeyValueObservation?
    private var accountObservation: NSKeyValueObservation?
    private var issuerObservation: NSKeyValueObservation?

    let progress: PieProgressBar = {
        let progress = PieProgressBar()
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.alpha = 0
        progress.tintColor = .placeholderText
        progress.frame.size = CGSize(width: 30, height: 30)
        return progress
    }()
    
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
    var codeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .largeTitle).withSize(45)
        return label
    }()
    var nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.textColor = .systemGray
        return label
    }()
    
    @objc dynamic let credential: Credential
        
    var menu = Menu(actions: [])
    var copyMenuAction = MenuAction(title: "", image: nil, action: {})
    var calculateMenuAction: MenuAction?

    init(credential: Credential, viewModel: OATHViewModel, parentViewController: UIViewController) {
        self.parentViewController = parentViewController
        self.credential = credential
        self.viewModel = viewModel
        self.progress.setProgress(to: !credential.code.isEmpty ? credential.remainingTime / Double(credential.period) : 0)
        self.containerHeightConstraint = container.heightAnchor.constraint(equalToConstant: 88)
        super.init(effect: nil)
        
        calculateMenuAction = credential.type == .HOTP || credential.requiresTouch || !viewModel.keyPluggedIn ? MenuAction(title: "Calculate", image: UIImage(systemName: "arrow.clockwise"), action: {
            viewModel.calculate(credential: credential)
            print("calculate")
        }) : nil
        
        copyMenuAction = {
            MenuAction(title: "Copy", image: UIImage(systemName: "square.and.arrow.up"),
                       action: {
                        viewModel.copyToClipboard(credential: credential)
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
                    editController.credential = credential
                    editController.viewModel = viewModel
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
        
        self.menu = Menu(actions: [calculateMenuAction,
                                   copyMenuAction,
                                   favoriteAction,
                                   editAction,
                                   deleteAction].compactMap{ $0 })
        self.menu.alpha = 0
        self.menu.translatesAutoresizingMaskIntoConstraints = false
        self.menu.layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        self.menu.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)

        self.contentView.addSubview(container)
        self.container.addSubview(codeLabel)
        self.container.addSubview(nameLabel)
        self.container.addSubview(progress)
        self.contentView.addSubview(menu)

        self.containerTopConstraint = container.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 0)
        self.containerCenterYConstraint = container.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor, constant: -70)
        self.containerCenterYConstraint?.priority = .defaultLow
        
        self.codeLabelTopConstraint = codeLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 5)
        self.codeLabelLeftConstraint = codeLabel.leftAnchor.constraint(equalTo: container.leftAnchor, constant: 49)

        let nameLabelRightMarginConstraint = nameLabel.rightAnchor.constraint(lessThanOrEqualTo: container.rightAnchor, constant: -20)
        let nameLabelLeftMarginConstraint = nameLabel.leftAnchor.constraint(lessThanOrEqualTo: container.rightAnchor, constant: 20)

        self.nameLabelTopConstraint = nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 49)
        self.nameLabelLeftConstraint = nameLabel.leftAnchor.constraint(equalTo: container.leftAnchor, constant: 50)
        self.nameLabelCenterConstraint = nameLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        self.nameLabelCenterConstraint?.priority = .defaultLow
        
        NSLayoutConstraint.activate([self.containerTopConstraint,
                                     self.containerCenterYConstraint,
                                     container.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 30),
                                     container.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -30),
                                     containerHeightConstraint,
                                     codeLabelTopConstraint,
                                     codeLabelLeftConstraint,
                                     nameLabelLeftMarginConstraint,
                                     nameLabelRightMarginConstraint,
                                     nameLabelTopConstraint,
                                     nameLabelLeftConstraint,
                                     nameLabelCenterConstraint,
                                     menu.centerXAnchor.constraint(equalTo: self.centerXAnchor, constant: 0),
                                     menu.centerYAnchor.constraint(equalTo: container.bottomAnchor, constant: 15), // Need to anchor to center since we have changed the anchorPoint
                                     progress.widthAnchor.constraint(equalToConstant: 30),
                                     progress.heightAnchor.constraint(equalToConstant: 30),
                                     progress.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
                                     progress.centerXAnchor.constraint(equalTo: container.centerXAnchor)
                ].compactMap { $0 }
        )
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
        self.contentView.addGestureRecognizer(tap)
        
        containerTopConstraint?.constant = from.y + 50
        
        refreshCode()
        refreshName()
        refreshProgress()
        layoutIfNeeded()
        codeLabel.applyTransform(withScale: 0.5, anchorPoint: CGPoint(x: 0, y: 0.5))
        
        UIView.animate(withDuration: 0.1) {
            self.container.alpha = 1
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            self.codeLabelTopConstraint?.constant = 20
            self.codeLabel.applyTransform(withScale: 1, anchorPoint: CGPoint(x: 0, y: 0.5))
            // The anchor point is on the middle left side so we have to calculate the margin manually
            self.codeLabelLeftConstraint?.constant = (self.container.frame.width - self.codeLabel.frame.width) / 2

            self.nameLabelLeftConstraint?.priority = .defaultLow
            self.nameLabelCenterConstraint?.priority = .required
            self.nameLabelTopConstraint?.constant = 75

            self.containerTopConstraint?.priority = .defaultLow
            self.containerCenterYConstraint?.priority = .required
            self.containerHeightConstraint.constant = 160
            self.layoutIfNeeded()
        }

        UIView.animate(withDuration: 0.1, delay: 0.1, options: .curveEaseInOut) {
            self.progress.alpha = self.credential.type == .TOTP ? 1 : 0
            self.menu.transform = .identity
            self.menu.alpha = 1
        }
    }
    
    @objc func dismiss() {
        UIView.animate(withDuration: 0.1, delay: 0.15, options: .curveEaseOut) {
            self.container.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
            self.effect = nil
            
            self.containerTopConstraint?.priority = .required
            self.containerCenterYConstraint?.priority = .defaultLow
            
            self.containerHeightConstraint.constant = 88
            
            self.codeLabel.applyTransform(withScale: 0.5, anchorPoint: CGPoint(x: 0, y: 0.5))
            self.codeLabelTopConstraint?.constant = 6
            self.codeLabelLeftConstraint?.constant = 49
            
            self.nameLabelLeftConstraint?.priority = .required
            self.nameLabelCenterConstraint?.priority = .defaultLow
            self.nameLabelTopConstraint?.constant = 49
            
            self.progress.alpha = 0
            
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
                guard let self = self else { return }
                self.refreshCode()
                self.layoutIfNeeded()
                // Changing the code changes the frame of the label and hence the anchorpoint will be off
                self.codeLabel.applyTransform(withScale: 1, anchorPoint: CGPoint(x: 0, y: 0.5))
                // The anchor point is on the middle left side so we have to calculate the margin manually
                self.codeLabelLeftConstraint?.constant = (self.container.frame.width - self.codeLabel.frame.width) / 2
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
        self.copyMenuAction.isEnabled = !credential.requiresRefresh
        if credential.state == .calculating {
            self.progress.isHidden = true
        } else if credential.type == .TOTP {
            self.calculateMenuAction?.isEnabled = credential.requiresRefresh
            if credential.remainingTime > 0 && !credential.code.isEmpty {
                UIView.animate(withDuration: 1) {
                    self.progress.setProgress(to: self.credential.remainingTime / Double(self.credential.period))
                }
            } else {
                // keeping old value of code on screen even if it's expired already
                self.progress.setProgress(to: Double(0.0))
                self.codeLabel.textColor = credential.requiresRefresh ? .secondaryLabel : .label
            }
        }
    }
    
    func refreshName() {
        nameLabel.text = credential.formattedName
    }
    
    func refreshCode() {
        let otp = credential.formattedCode
        self.codeLabel.text = otp
        if credential.type == .TOTP {
            self.codeLabel.textColor = credential.requiresRefresh ? .secondaryLabel : .label
        } else {
            self.codeLabel.textColor = credential.code.isEmpty ? .secondaryLabel : .label
        }
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
