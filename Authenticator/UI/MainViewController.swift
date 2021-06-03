//
//  MainViewController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-17.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation
import UIKit

class MainViewController: UITableViewController {
    @IBOutlet weak var imageAlignmentConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageView: UIImageView!
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if #available(iOS 14.0, *) {
            if let tokenRequestController = segue.destination as? TokenRequestViewController, let userInfo = sender as? [AnyHashable: Any] {
                tokenRequestController.userInfo = userInfo
            }
        }
    }
}

extension MainViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let yOffset = -scrollView.contentOffset.y
        if yOffset > 94 && yOffset < 170 {
            imageHeightConstraint.constant = 41 * yOffset / 94
            imageWidthConstraint.constant = 150 * yOffset / 94
        }
        if yOffset < 70 {
            imageView.alpha = max(0, 1 + (yOffset - 70) / 60)
        }
        imageAlignmentConstraint.constant = (94 - yOffset) / 2.2
    }
}

extension MainViewController: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        performSegue(withIdentifier: "handleTokenRequest", sender: response.notification.request.content.userInfo)
        completionHandler()
    }
}
