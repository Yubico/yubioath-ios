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

class ScanAccountController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    init(completionHandler: @escaping (YKFOATHCredentialTemplate?) -> ()) {
        self.completionHandler = completionHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    private let completionHandler: (YKFOATHCredentialTemplate?) -> ()
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
        label.text = "Point your camera at a QR code to scan it"
        label.textColor = .white
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .footnote).withSymbolicTraits(.traitBold)
        return label
    }()
    
    private let errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "No account information in QR code!"
        label.textColor = .red
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .title3).withSymbolicTraits(.traitBold)
        label.alpha = 0
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else { return }
        guard captureSession.canAddInput(videoInput) else { return }
        captureSession.addInput(videoInput)
        guard captureSession.canAddOutput(metadataOutput) else { return }
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]
        
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)
        let overlay = createOverlay()
        
        cancellables.append(closeButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.dismiss(animated: true)
        })
        
        cancellables.append(addManuallyButton.addHandler(for: .touchUpInside) { [weak self] in
            self?.dismiss(animated: true)
            self?.completionHandler(nil)
        })
        
        overlay.addSubview(closeButton)
        overlay.addSubview(addAccountLabel)
        overlay.addSubview(addManuallyButton)
        overlay.addSubview(textLabel)
        overlay.addSubview(errorLabel)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -20),
            addAccountLabel.topAnchor.constraint(equalTo: overlay.topAnchor, constant: 15),
            addAccountLabel.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            addManuallyButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            addManuallyButton.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -55),
            textLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -10),
            textLabel.topAnchor.constraint(equalTo: overlay.topAnchor, constant: overlay.frame.height / 1.6),
            errorLabel.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 10),
            errorLabel.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -10),
            errorLabel.topAnchor.constraint(equalTo: overlay.topAnchor, constant: overlay.frame.height / 5.0)
        ])
        
        view.addSubview(overlay)
        
        captureSession.startRunning()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        metadataOutput.rectOfInterest =  previewLayer.metadataOutputRectConverted(fromLayerRect: captureRect())
        if (captureSession.isRunning == false) {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if (captureSession.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard lastScanDate.timeIntervalSinceNow < -5 else { return }
        lastScanDate = Date()
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }
        guard let url = URL(string: stringValue),
              let credential = YKFOATHCredentialTemplate(url: url) else {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            showError()
            return
        }
        captureSession.stopRunning()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        dismiss(animated: true)
        completionHandler(credential)
    }
    
    func showError() {
        UIView.animate(withDuration: 0.5) {
            self.errorLabel.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.5, delay: 4.0) {
              self.errorLabel.alpha = 0
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


extension ScanAccountController {
    
    func captureRect() -> CGRect {
        let margin = 50.0
        let size = view.frame.width - margin * 2
        return CGRect(x: margin,
                      y: view.center.y - size / 1.5,
                      width: size,
                      height: size)
    }
    
    func createOverlay() -> UIView {
        
        let overlayView = UIView(frame: view.frame)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        let path = CGMutablePath()
        path.addRoundedRect(in: captureRect(), cornerWidth: 15, cornerHeight: 15)
        path.closeSubpath()
        
        let shape = CAShapeLayer()
        shape.path = path
        shape.lineWidth = 5.0
        shape.strokeColor = UIColor.yubiGreen.cgColor
        shape.fillColor = UIColor.yubiGreen.cgColor
        
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
