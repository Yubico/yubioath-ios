//
//  ServicesViewController.swift
//  Authenticator
//
//  Created by Jens Utbult on 2021-05-17.
//  Copyright © 2021 Yubico. All rights reserved.
//

import Foundation


class ServicesViewController: UITableViewController {
    @IBOutlet weak var imageAlignmentConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageView: UIImageView!
}

extension ServicesViewController { //}: UITableViewDelegate {
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
