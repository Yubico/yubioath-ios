//
//  FreViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

class FreViewController: UIViewController {

    private var isLastPage = false
    
    private weak var frePageViewController: FrePageViewController? {
        didSet {
         //   FrePageViewController.freDelegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let skipButton = UIBarButtonItem(title: "Skip", style: .done, target: self, action: #selector(didTapSkipButton))
        navigationItem.rightBarButtonItem = skipButton
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isTranslucent = false
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let frePageVC = segue.destination as? FrePageViewController {
            self.frePageViewController = frePageVC
        }
    }
    
    @objc func didTapSkipButton() {
        finishFRE()
    }
    
    private func finishFRE() {
        // UserDefaults
        navigationController?.dismiss(animated: true, completion: nil)
    }
}

//extension FreViewController: FrePageViewControllerDelegate {
//    func pageViewController(didUpdatePageIndex index: Int, count: Int) {
//        updateButtons
//    }
//}
