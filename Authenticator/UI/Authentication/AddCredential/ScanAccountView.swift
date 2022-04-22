//
//  ScanAccountController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2022-03-14.
//  Copyright © 2022 Yubico. All rights reserved.
//

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
        button.setTitle("Manual entry", for: .normal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        button.layer.cornerRadius = 20
        button.layer.borderColor = UIColor.white.cgColor
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
    
    private let textLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = ScanAccountView.scanMessage
        label.textColor = .white
        label.textAlignment = .center
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
    
    private var errorOverlay: UIView?
    
    init(frame: CGRect, completionHandler: @escaping (ScanResult) -> ()) {
        self.completionHandler = completionHandler
        super.init(frame: frame)

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        guard captureSession.canAddInput(videoInput) else { return }
        captureSession.addInput(videoInput)
        guard captureSession.canAddOutput(metadataOutput) else { return }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]
        
        previewLayer.frame = layer.bounds
        layer.addSublayer(previewLayer)
        let overlay = createOverlay()
        
        cancellables.append(closeButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.completionHandler(.cancel)
        })
        
        cancellables.append(addManuallyButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.completionHandler(.manuelEntry)
            self?.removeFromSuperview()
        })
        
        overlay.addSubview(closeButton)
        overlay.addSubview(addAccountLabel)
        overlay.addSubview(addManuallyButton)
        overlay.addSubview(textLabel)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -20),
            addAccountLabel.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 15),
            addAccountLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            addManuallyButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            addManuallyButton.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -55),
            textLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -10),
            textLabel.topAnchor.constraint(equalTo: overlay.topAnchor, constant: overlay.frame.height / 1.55)
        ])
        
        addSubview(overlay)
        
        errorOverlay = createOverlay(frameColor: .red, background: .clear)
        errorOverlay?.alpha = 0
        addSubview(errorOverlay!)
        
        addSubview(checkboxImageView)
        
        let rect = captureRect()
        checkboxImageView.center = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)

        captureSession.startRunning()

        metadataOutput.rectOfInterest =  previewLayer.metadataOutputRectConverted(fromLayerRect: captureRect())
        if (captureSession.isRunning == false) {
            captureSession.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard lastScanDate.timeIntervalSinceNow < -2 else { return }
        lastScanDate = Date()
        self.layer.removeAllAnimations()
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        guard let url = URL(string: stringValue) else {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            showError("No account information found!")
            return
        }
        
        let credential: YKFOATHCredentialTemplate
        do {
            credential = try YKFOATHCredentialTemplate(url: url, error: ())
        } catch {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            showError("\(error.localizedDescription)!")
            return
        }
        
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
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
    
    func showError(_ message: String) {
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


extension ScanAccountView {
    
    func captureRect() -> CGRect {
        let margin = 50.0
        let size = frame.width - margin * 2
        return CGRect(x: margin,
                      y: center.y - size / 1.5,
                      width: size,
                      height: size)
    }
    
    func createOverlay(frameColor: UIColor = .yubiGreen, background: UIColor = UIColor.black.withAlphaComponent(0.6)) -> UIView {
        
        let overlayView = UIView(frame: frame)
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
