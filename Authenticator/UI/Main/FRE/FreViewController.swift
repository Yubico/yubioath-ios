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
            frePageViewController?.freDelegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let skipButton = UIBarButtonItem(title: "Skip", style: .done, target: self, action: #selector(didTapSkipButton))
        let nextButton = UIBarButtonItem(title: "Next", style: .done, target: self, action: #selector(didTapNextButton))
        self.navigationItem.leftBarButtonItem = skipButton
        self.navigationItem.rightBarButtonItem = nextButton
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let frePageVC = segue.destination as? FrePageViewController {
            self.frePageViewController = frePageVC
        }
    }
    
    @objc func didTapSkipButton() {
        finishFRE()
    }
    
    @objc func didTapNextButton() {
        if isLastPage {
            finishFRE()
        } else {
            frePageViewController?.scrollNext()
        }
    }
    
    private func finishFRE() {
        UserDefaults.standard.freFinished = true
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
}

extension FreViewController: FrePageViewControllerDelegate {
    func pageViewController(didUpdatePageIndex index: Int, count: Int) {
        isLastPage = index == count - 1
    }
}
