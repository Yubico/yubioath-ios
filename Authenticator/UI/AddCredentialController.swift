//
//  AddCredentialController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/18/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class AddCredentialController: UITableViewController {

    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var addScannedButton: UIButton!
    @IBOutlet weak var issuerScannedText: UITextField!
    @IBOutlet weak var accountScannedText: UITextField!
    @IBOutlet weak var addManualButton: UIButton!
    @IBOutlet weak var issuerManualText: UITextField!
    @IBOutlet weak var accountManualText: UITextField!
    @IBOutlet weak var secretManualText: UITextField!
    
    private var url: URL?
    private var manualEntryExpanded: Bool = false

    /*
     This value is either passed by `MainViewController` in `prepare(for:sender:)`
     or constructed as part of scanning/manual input operation.
     */
    var credential: YKFOATHCredential?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // if QR codes are anavailable on device disable button
        scanButton.isEnabled = YubiKitDeviceCapabilities.supportsQRCodeScanning
        
        // For removing the extra empty spaces of TableView below
        tableView.tableFooterView = UIView()
    }
    
    // MARK: - Table view cell sizes

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 0 {
            manualEntryExpanded = !manualEntryExpanded
            tableView.beginUpdates()
            tableView.endUpdates()
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && indexPath.row == 0 {
            if (url == nil) {
                // first cell collapsed 140
                return 140
            } else {
                return 340
            }
        }
        if indexPath.section == 1 && indexPath.row == 0 {
            if manualEntryExpanded {
                return 350
            } else {
                return 70
            }
        }
        return 80
    }
    
    
    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    
    @IBAction func scanQRCodeButtonPressed(_ sender: Any) {
        YubiKitManager.shared.qrReaderSession.scanQrCode(withPresenter: self) {
            [weak self] (payload, error) in
            guard self != nil else {
                return
            }
            guard error == nil else {
                // TODO: handle error
                return
            }
            
            // This is an URL conforming to Key URI Format specs.
            guard let url = URL(string: payload!) else {
                fatalError()
            }
            
            guard let credential = YKFOATHCredential(url: url) else {
                print("Invalid URI format")
                return
            }

            self?.issuerScannedText.text = credential.issuer
            self?.accountScannedText.text = credential.account
            self?.url = url
            self?.tableView.beginUpdates()
            self?.tableView.endUpdates()
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if let button = sender as? UIBarButtonItem, button === saveButton {
            let oathUrlString = "otpauth://totp/Yubico:example@yubico.com?secret=UOA6FJYR76R7IRZBGDJKLYICL3MUR7QH&issuer=Yubico&algorithm=SHA1&digits=6&period=30";
            self.credential = YKFOATHCredential(url: URL(string: oathUrlString)!)
            return
        }
 
        if let button = sender as? UIButton, button == addScannedButton, self.url != nil {
            // Create the credential from the URL using the convenience initializer.
            guard let credential = YKFOATHCredential(url: self.url!) else {
                print("Invalid URI format")
                return
            }
            
            // Set the credential to be passed to MainViewController after the unwind segue.
            credential.issuer = self.issuerScannedText.text ?? ""
            credential.account = self.accountScannedText.text ?? ""
            
            self.credential = credential
        } else if let button = sender as? UIButton, button == addManualButton {
            // Create the credential from manual input
            let credential = YKFOATHCredential()
            
            // Set the credential to be passed to MainViewController after the unwind segue.
            credential.issuer = self.issuerManualText.text ?? ""
            credential.account = self.accountManualText.text ?? ""
            
            if let base32DecodedSecret = NSData.ykf_data(withBase32String: self.secretManualText.text ?? "") {
                // use the base32DecodeData (of type Data) and set it on the credential:
                credential.secret = base32DecodedSecret
                self.credential = credential
            } else {
                // TODO: validate it before unwind segue and prevent user from adding it
                print("Invalid Base32 encoded string")
            }
            self.credential = credential
        } else {
            print("The save button was not pressed, cancelling")
        }
        //            self!.performSegue(withIdentifier: "SuccessfulScan", sender: self)

    }

}
