/*
 * Copyright (C) 2022 Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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
import AVKit
import UIKit
import YubiKit
import Combine
import CloudKit

class ScanAccountView: UIView, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    
    enum ScanResult {
        case cancel, manuelEntry, account(YubiKitOATHSession.CredentialTemplate)
    }
    
    private static let scanMessage = String(localized: "Point your camera at a QR code to scan it", comment: "Scan QR code message")

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
        button.setTitle(String(localized: "Close", comment: "View close button"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        return button
    }()
    
    private let addManuallyButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = String(localized: "Enter manually", comment: "Scan QR code add manually button")
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 15, bottom: 8, trailing: 15)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .body)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.layer.cornerRadius = 20
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 2
        return button
    }()
    
    private let openSettingsButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.title = String(localized: "Open iOS Settings app", comment: "Scan QR code settings button")
        configuration.baseForegroundColor = .white
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 15, bottom: 8, trailing: 15)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .body)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 20
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.layer.borderWidth = 2
        return button
    }()
    
    private let addAccountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "Add account", comment: "Scan QR code add account label")
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .body).withSymbolicTraits(.traitBold)
        return label
    }()
    
    private let noQRCodeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = String(localized: "No QR code?", comment: "Scan QR code no QR code message")
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
//        if #available(iOS 15.0, *) {
//            configuration = configuration.applying(UIImage.SymbolConfiguration(paletteColors: [.white, .yubiGreen]))
//        }
        let image = UIImage(systemName: "checkmark.circle.fill")?.withConfiguration(configuration)
        let imageView = UIImageView(image: image)
//        imageView.tintColor = .yubiGreen
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
        title.text = String(localized: "No camera permissions", comment: "Scan QR code camera error title")
        title.textColor = .white
        view.addArrangedSubview(title)
        let text = UILabel()
        text.font = .preferredFont(forTextStyle: .body)
        text.translatesAutoresizingMaskIntoConstraints = false
        text.numberOfLines = 0
        text.text = String(localized: "To scan a QR code you need to enable camera permissions for the Authenticator app.", comment: "Scan QR code camera error message")
        text.textColor = .lightGray
        text.textAlignment = .center
        view.addArrangedSubview(text)
        view.setCustomSpacing(25, after: text)
        view.addArrangedSubview(openSettingsButton)
        return view
    }()
    
    private var overlay: UIView?
    private var errorOverlay: UIView?
    private var textLabelTopConstraint: NSLayoutConstraint?
    private var lastLayoutSize: CGSize = .zero
    private var lastContentRect: CGRect = .zero
    // Follows contentRect, so the controls stay inside the safe area and clear of the fold and the camera housing.
    private let contentGuide = UILayoutGuide()
    private var contentGuideConstraints = [NSLayoutConstraint]()

    // Serializes starting the session and switching cameras off the main thread.
    private let sessionQueue = DispatchQueue(label: "com.yubico.authenticator.scan-session")
    private var activeCameraID: String?
    private var switchingToCameraID: String?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    // An AVCaptureDeviceDirectionCoordinator on iOS 27.1 and later.
    private var directionCoordinator: AnyObject?

    init(frame: CGRect, completionHandler: @escaping (ScanResult) -> ()) {
        self.completionHandler = completionHandler
        super.init(frame: frame)
        
        self.accessibilityViewIsModal = true
        
        previewLayer.frame = layer.bounds
        layer.addSublayer(previewLayer)

        addLayoutGuide(contentGuide)
        contentGuideConstraints = [
            contentGuide.leftAnchor.constraint(equalTo: leftAnchor),
            contentGuide.topAnchor.constraint(equalTo: topAnchor),
            contentGuide.widthAnchor.constraint(equalToConstant: 0),
            contentGuide.heightAnchor.constraint(equalToConstant: 0)
        ]
        NSLayoutConstraint.activate(contentGuideConstraints)

        layoutOverlays()

        cancellables.append(closeButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.completionHandler(.cancel)
        })
        
        cancellables.append(addManuallyButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.completionHandler(.manuelEntry)
            self?.removeFromSuperview()
        })
        
        cancellables.append(openSettingsButton.addHandler(for: .touchUpInside) {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
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
        
        let textLabelTopConstraint = textLabel.topAnchor.constraint(equalTo: topAnchor, constant: captureRect().maxY + 16)
        self.textLabelTopConstraint = textLabelTopConstraint

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -20),
            addAccountLabel.topAnchor.constraint(equalTo: contentGuide.topAnchor, constant: 15),
            addAccountLabel.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            noQRCodeLabel.bottomAnchor.constraint(equalTo: addManuallyButton.topAnchor, constant: -15),
            noQRCodeLabel.centerXAnchor.constraint(equalTo: addManuallyButton.centerXAnchor),
            addManuallyButton.centerXAnchor.constraint(equalTo: contentGuide.centerXAnchor),
            addManuallyButton.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor, constant: -55),
            textLabel.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -10),
            textLabelTopConstraint,
            permissionView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor, constant: 50),
            permissionView.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor, constant: -50),
            permissionView.centerYAnchor.constraint(equalTo: contentGuide.centerYAnchor, constant: -50)
        ])
        
        addSubview(checkboxImageView)
        
        let rect = captureRect()
        checkboxImageView.center = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
    
        previewLayer.backgroundColor = UIColor(white: 0.2, alpha: 1).cgColor
        
        Task {
            let result = await AVCaptureDevice.requestAccess(for: .video)
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
                // Kept: AVFoundation takes a dispatch queue for delegate callbacks, and the delegate is main actor isolated.
                self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                self.metadataOutput.metadataObjectTypes = [.qr]
                self.activeCameraID = videoCaptureDevice.uniqueID
                self.observeRotation(of: videoCaptureDevice)
                if #available(iOS 27.1, *) {
                    self.observeCameraDirections()
                }
                // AVCaptureSession is meant to be started off the main thread.
                nonisolated(unsafe) let captureSession = self.captureSession
                self.sessionQueue.async { [weak self] in
                    if (captureSession.isRunning == false) {
                        captureSession.startRunning()
                    }
                    // The preview can only convert the scan area to metadata coordinates once the session is running.
                    DispatchQueue.main.async {
                        self?.updateVideoOrientation()
                    }
                }
            } else {
                self.showPermissionError()
            }
        }
    }
    
    override func layoutSubviews() {
        // Before super, so the content guide constraints updated here apply in this layout pass.
        if bounds.size != lastLayoutSize || contentRect != lastContentRect {
            layoutOverlays()
        }
        super.layoutSubviews()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        setNeedsLayout()
    }

    // Rebuilds the capture overlays for the current size so the scan area stays inside the view on every display, orientation and pose.
    private func layoutOverlays() {
        let contentRect = self.contentRect
        lastLayoutSize = bounds.size
        lastContentRect = contentRect
        contentGuideConstraints[0].constant = contentRect.minX
        contentGuideConstraints[1].constant = contentRect.minY
        contentGuideConstraints[2].constant = contentRect.width
        contentGuideConstraints[3].constant = contentRect.height
        previewLayer.frame = layer.bounds

        let errorAlpha = errorOverlay?.alpha ?? 0
        overlay?.removeFromSuperview()
        errorOverlay?.removeFromSuperview()

        let overlay = createOverlay()
        insertSubview(overlay, at: 0)
        self.overlay = overlay

        let errorOverlay = createOverlay(frameColor: .red, background: .clear)
        errorOverlay.alpha = errorAlpha
        insertSubview(errorOverlay, aboveSubview: overlay)
        self.errorOverlay = errorOverlay

        // Inserting a subview at index 0 can put its layer under the preview layer, which is a plain sublayer,
        // so move the preview back to the bottom or it hides the overlays.
        layer.insertSublayer(previewLayer, at: 0)

        let rect = captureRect()
        textLabelTopConstraint?.constant = rect.maxY + 16
        checkboxImageView.center = CGPoint(x: rect.midX, y: rect.midY)
        updateRectOfInterest()
    }

    // Before the session runs the preview doesn't know the video dimensions and converts to a wrong rect, which can keep
    // QR codes inside the scan frame from being read. Starting the session updates it again.
    private func updateRectOfInterest() {
        guard captureSession.isRunning else { return }
        metadataOutput.rectOfInterest = previewLayer.metadataOutputRectConverted(fromLayerRect: captureRect())
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
        // The rotation coordinator accounts for the interface orientation and, on iPhone Duo, for the display the app is on,
        // which a fixed mapping from the device orientation can't.
        if let rotationAngle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview,
           let connection = self.previewLayer.connection, connection.isVideoRotationAngleSupported(rotationAngle) {
            connection.videoRotationAngle = rotationAngle
        }
        updateRectOfInterest()
    }

    // A rotation coordinator reports angles for a single camera, so this runs again for each camera the scanner switches to.
    private func observeRotation(of device: AVCaptureDevice) {
        let rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        self.rotationCoordinator = rotationCoordinator
        rotationObservation = rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.updateVideoOrientation()
            }
        }
    }

    // The scanner reads a QR code held in front of the device, so it captures from a camera that faces away from the person.
    // On iPhone Duo that changes as the device opens, closes and turns around, so follow the cameras' direction relative to
    // this view rather than trusting their position.
    @available(iOS 27.1, *)
    private func observeCameraDirections() {
        directionCoordinator = AVCaptureDeviceDirectionCoordinator(
            view: self,
            deviceTypes: [.builtInWideAngleCamera, .builtInOuterUltraWideCamera, .builtInInnerUltraWideCamera]
        ) { [weak self] deviceDirections in
            self?.cameraDirectionsDidChange(deviceDirections)
        }
    }

    @available(iOS 27.1, *)
    private func cameraDirectionsDidChange(_ deviceDirections: AVCaptureDeviceDirectionMap) {
        let backwardFacing = deviceDirections.backwardFacingDeviceDescriptors
        // A switch already on its way to a backward facing camera will settle this change too.
        if backwardFacing.contains(where: { $0.uniqueID == (switchingToCameraID ?? activeCameraID) }) { return }
        // Prefer a rear camera, which focuses closer than the ultra wide cameras.
        guard let replacement = backwardFacing.first(where: { $0.position == .back }) ?? backwardFacing.first else { return }
        switchingToCameraID = replacement.uniqueID
        // Hide frames from the outgoing camera while the new one starts.
        previewLayer.opacity = 0

        let uniqueID = replacement.uniqueID
        nonisolated(unsafe) let captureSession = self.captureSession
        sessionQueue.async { [weak self] in
            var didSwitch = false
            if let device = AVCaptureDevice(uniqueID: uniqueID),
               let newInput = try? AVCaptureDeviceInput(device: device) {
                captureSession.beginConfiguration()
                let previousInputs = captureSession.inputs
                previousInputs.forEach { captureSession.removeInput($0) }
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                    didSwitch = true
                } else {
                    previousInputs.forEach { captureSession.addInput($0) }
                }
                captureSession.commitConfiguration()
            }
            DispatchQueue.main.async {
                self?.cameraSwitchDidFinish(switchedTo: didSwitch ? uniqueID : nil)
            }
        }
    }

    // Called with nil when the switch failed and the previous camera is still capturing.
    private func cameraSwitchDidFinish(switchedTo uniqueID: String?) {
        switchingToCameraID = nil
        if let uniqueID {
            activeCameraID = uniqueID
            if let device = AVCaptureDevice(uniqueID: uniqueID) {
                observeRotation(of: device)
            }
            // The connection mirrors front cameras automatically, but the active camera always faces away from the person,
            // so its preview is never mirrored. The new input creates a new connection, which needs this again.
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        updateVideoOrientation()
        previewLayer.opacity = 1
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
            showError(String(localized: "No account information found!", comment: "Scan QR code no account error message"))
            return
        }
        
        let credential: YubiKitOATHSession.CredentialTemplate
        do {
            credential = try YubiKitOATHSession.CredentialTemplate(otpauthURL: url, skip: [.issuer, .label])
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
        
        Task {
            try? await Task.sleep(for: .seconds(1))
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
    
    // The part of the bounds the scanner lays out its controls and scan area in: inside the safe area, and the largest
    // part of it that the fold and the camera housing leave clear.
    private var contentRect: CGRect {
        let clearRect = boundsClearOfReservedRegions
        let safeRect = clearRect.intersection(bounds.inset(by: safeAreaInsets))
        return safeRect.isNull ? clearRect : safeRect
    }

    // Sized from the view's own bounds rather than the device idiom, so the scan area fits compact and regular widths in any orientation.
    private func captureRect() -> CGRect {
        let area = contentRect
        let size = max(0, min(area.width - 100, area.height * 0.5, 500))
        let result = CGRect(x: area.midX - size / 2,
                            y: area.midY - size / 1.5,
                            width: size,
                            height: size)
        return result
    }

    private func createOverlay(frameColor: UIColor = .systemGreen, background: UIColor = UIColor.black.withAlphaComponent(0.6)) -> UIView {

        let overlayView = UIView(frame: bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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
