//
//  AddFromScanViewController.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/27/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class AddFromScanViewController: UIViewController {

    @IBOutlet weak var addButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.

        guard let button = sender as? UIButton, button === addButton else {
            print("The add button was not pressed, cancelling")
            return
        }
        
        // Set the credential to be passed to MainViewController after the unwind segue.
        let credential = YKFOATHCredential()
        credential.issuer = "issuer"
        credential.account = "name"
        
        self.credential = credential
    }
    

}
