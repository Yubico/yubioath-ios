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

import AVFoundation
import UIKit
import Combine
import CloudKit

class ScanAccountView: UIView, AVCaptureMetadataOutputObjectsDelegate {
    
    enum ScanResult {
        case cancel, manuelEntry, account(YKFOATHCredentialTemplate)
    }
    
    private static let scanMessage = "Point your camera at a QR code to scan it"

    private let completionHandler: (ScanResult) -> ()
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }()
    private let metadataOutput = AVCaptureMetadataOutput()
    private var lastScanDate = Date(timeIntervalSince1970: 0)
    private var cancellables = [Cancellable]()

    private let closeButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Close", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        return button
    }()
    
    private let addManuallyButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Enter manually", for: .normal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.layer.cornerRadius = 20
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 2
        button.contentEdgeInsets =  UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()
    
    private let openSettingsButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Open iOS Settings app", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.layer.cornerRadius = 20
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 2
        button.contentEdgeInsets =  UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()
    
    private let addAccountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Add account"
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .body).withSymbolicTraits(.traitBold)
        return label
    }()
    
    private let noQRCodeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No QR code?"
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .footnote).withSymbolicTraits(.traitBold)
        return label
    }()
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = ScanAccountView.scanMessage
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .footnote).withSymbolicTraits(.traitBold)
        return label
    }()
    
    private let checkboxImageView: UIImageView = {
        var configuration = UIImage.SymbolConfiguration(pointSize: 250)
        if #available(iOS 15.0, *) {
            configuration = configuration.applying(UIImage.SymbolConfiguration(paletteColors: [.white, .yubiGreen]))
        }
        let image = UIImage(systemName: "checkmark.circle.fill")?.withConfiguration(configuration)
        let imageView = UIImageView(image: image)
        imageView.tintColor = .yubiGreen
        imageView.transform = CGAffineTransform(scaleX: 2.5, y: 2.5)
        imageView.alpha = 0
        return imageView
    }()
    
    private lazy var permissionView: UIView = {
        let view = UIStackView()
        view.alpha = 0
        view.isHidden = true
        view.axis = .vertical
        view.spacing = 15
        view.alignment = .center
        view.translatesAutoresizingMaskIntoConstraints = false
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.numberOfLines = 0
        title.font = .preferredFont(forTextStyle: .title2)
        title.textAlignment = .center
        title.text = "No camera permissions"
        title.textColor = .white
        view.addArrangedSubview(title)
        let text = UILabel()
        text.font = .preferredFont(forTextStyle: .body)
        text.translatesAutoresizingMaskIntoConstraints = false
        text.numberOfLines = 0
        text.text = "To scan a QR code you need to enable camera permissions for the Authenticator app."
        text.textColor = .lightGray
        text.textAlignment = .center
        view.addArrangedSubview(text)
        view.setCustomSpacing(25, after: text)
        view.addArrangedSubview(openSettingsButton)
        return view
    }()
    
    private var errorOverlay: UIView?
    
    init(frame: CGRect, completionHandler: @escaping (ScanResult) -> ()) {
        self.completionHandler = completionHandler
        super.init(frame: frame)
        
        previewLayer.frame = layer.bounds
        layer.addSublayer(previewLayer)
        
        addSubview(createOverlay())
        
        errorOverlay = createOverlay(frameColor: .red, background: .clear)
        errorOverlay?.alpha = 0
        if let errorOverlay = errorOverlay {
            addSubview(errorOverlay)
        }
        
        cancellables.append(closeButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.completionHandler(.cancel)
        })
        
        cancellables.append(addManuallyButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.completionHandler(.manuelEntry)
            self?.removeFromSuperview()
        })
        
        cancellables.append(openSettingsButton.addHandler(for: .touchUpInside) {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(settingsUrl) else {
                return
            }
            UIApplication.shared.open(settingsUrl)
        })
        
        addSubview(closeButton)
        addSubview(addAccountLabel)
        addSubview(textLabel)
        addSubview(noQRCodeLabel)
        addSubview(addManuallyButton)
        addSubview(permissionView)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            addAccountLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            addAccountLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            noQRCodeLabel.bottomAnchor.constraint(equalTo: addManuallyButton.topAnchor, constant: -15),
            noQRCodeLabel.centerXAnchor.constraint(equalTo: addManuallyButton.centerXAnchor),
            addManuallyButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            addManuallyButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -55),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: UIDevice.current.userInterfaceIdiom == .pad ? 540.0 : frame.height / 1.55),
            permissionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            permissionView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -50),
            permissionView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -50)
        ])
        
        addSubview(checkboxImageView)
        
        let rect = captureRect()
        checkboxImageView.center = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
    
        previewLayer.backgroundColor = UIColor(white: 0.2, alpha: 1).cgColor
        
        AVCaptureDevice.requestAccess(for: .video) { result in
            DispatchQueue.main.async {
                if result {
                    guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
                        self.showPermissionError()
                        return
                    }
                    guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
                        self.showPermissionError()
                        return
                    }
                    guard self.captureSession.canAddInput(videoInput) else {
                        self.showPermissionError()
                        return
                    }
                    self.captureSession.addInput(videoInput)
                    guard self.captureSession.canAddOutput(self.metadataOutput) else { return }
                    self.captureSession.addOutput(self.metadataOutput)
                    self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                    self.metadataOutput.metadataObjectTypes = [.qr]
                    self.updateVideoOrientation()
                    DispatchQueue.global(qos: .userInitiated).async {
                        if (self.captureSession.isRunning == false) {
                            self.captureSession.startRunning()
                        }
                    }
                } else {
                    self.showPermissionError()
                }
            }
        }
    }
    
    func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(
            alongsideTransition: { _ in
                // Depending on if we grow or shrink the previewLayer we need to do it after or before the transition.
                if UIDevice.current.orientation.isPortrait {
                    self.previewLayer.frame = self.layer.bounds
                }
            },
            completion: { _ in
                if UIDevice.current.orientation.isLandscape {
                    self.previewLayer.frame = self.layer.bounds
                }
                self.updateVideoOrientation()
            }
        )
    }
    
    func updateVideoOrientation() {
        switch (UIDevice.current.orientation) {
         case .portrait:
            self.previewLayer.connection?.videoOrientation = .portrait
         case .landscapeLeft:
            self.previewLayer.connection?.videoOrientation = .landscapeRight
         case .landscapeRight:
            self.previewLayer.connection?.videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            self.previewLayer.connection?.videoOrientation = .portraitUpsideDown
         default:
             // This will be fallback when device is placed flat on i.e a table
            self.previewLayer.connection?.videoOrientation = .portrait
         }
        self.metadataOutput.rectOfInterest =  self.previewLayer.metadataOutputRectConverted(fromLayerRect: self.captureRect())
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard lastScanDate.timeIntervalSinceNow < -2 else { return }
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        lastScanDate = Date()
        self.layer.removeAllAnimations()
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        guard let url = URL(string: stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            showError("No account information found!")
            return
        }
        
        let credential: YKFOATHCredentialTemplate
        do {
            credential = try YKFOATHCredentialTemplate(url: url, skip: [.issuer, .label])
        } catch {
            showError("\(error.localizedDescription)!")
            return
        }
        
        self.errorOverlay?.isHidden = true
        UIView.animate(withDuration: 0.2) {
            self.textLabel.text = Self.scanMessage
            self.checkboxImageView.alpha = 1
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            self.textLabel.text = Self.scanMessage
            self.checkboxImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        }
        
        UIView.animate(withDuration: 0.3, delay: 0.7, options: .curveEaseIn) {
            self.alpha = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.captureSession.stopRunning()
            self.completionHandler(.account(credential))
            self.removeFromSuperview()
        }
    }
    
    private func showError(_ message: String) {
        UIView.animate(withDuration: 0.5) {
            self.errorOverlay?.alpha = 1
            self.textLabel.text = message
        } completion: { completed in
            guard completed else { return }
            UIView.animate(withDuration: 0.5, delay: 4.0) {
                self.errorOverlay?.alpha = 0
            } completion: { completed in
                guard completed else { return }
                self.textLabel.text = Self.scanMessage
            }
        }
    }
    
    private func showPermissionError() {
        if self.permissionView.isHidden {
            self.permissionView.isHidden = false
            UIView.animate(withDuration: 0.7) {
                self.permissionView.alpha = 1
                self.errorOverlay?.alpha = 1
                self.textLabel.textColor = .darkGray
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


extension ScanAccountView {
    
    private func captureRect() -> CGRect {
        let margin = UIDevice.current.userInterfaceIdiom == .pad  ? 150.0 : 50.0
        let size = frame.width - margin * 2
        let result = CGRect(x: margin,
                            y: UIDevice.current.userInterfaceIdiom == .pad ? 120.0 : center.y - size / 1.5,
                            width: size,
                            height: size)
        return result
    }
    
    private func createOverlay(frameColor: UIColor = .yubiGreen, background: UIColor = UIColor.black.withAlphaComponent(0.6)) -> UIView {
        
        let overlayView = UIView(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: frame.size.width, height: frame.size.height * 1.5)) // make size 50% larger than needed to handle orientation changes from landscape to portrait
        overlayView.backgroundColor = background
        
        let path = CGMutablePath()
        path.addRoundedRect(in: captureRect(), cornerWidth: 15, cornerHeight: 15)
        path.closeSubpath()
        
        let shape = CAShapeLayer()
        shape.path = path
        shape.lineWidth = 6.0
        shape.strokeColor = frameColor.cgColor
        shape.fillColor = UIColor.clear.cgColor
        
        overlayView.layer.addSublayer(shape)
        
        path.addRect(CGRect(origin: .zero, size: overlayView.frame.size))
        
        let maskLayer = CAShapeLayer()
        maskLayer.backgroundColor = UIColor.black.cgColor
        maskLayer.path = path
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        
        overlayView.layer.mask = maskLayer
        overlayView.clipsToBounds = true
        
        return overlayView
    }
}
