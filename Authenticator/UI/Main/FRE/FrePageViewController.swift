//
//  FrePageViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

protocol FrePageViewControllerDelegate: class {
    func pageViewController(didUpdatePageIndex index: Int, count: Int)
}

class FrePageViewController: UIPageViewController {

    weak var freDelegate: FrePageViewControllerDelegate?
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        [FrePageViewController.createViewController(withIdentifier: "FreWelcomeViewController"),
         FrePageViewController.createViewController(withIdentifier: "FreNfcViewController"),
         FrePageViewController.createViewController(withIdentifier: "FreQRViewController"),
        ]
    }()
    
    private var pageControl = UIPageControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        dataSource = self
        
        if let initialViewController = orderedViewControllers.first {
            scrollToViewController(viewController: initialViewController)
        }
        
        self.pageControl.frame = CGRect()
        self.pageControl.currentPageIndicatorTintColor = UIColor(named: "YubiGreen")
        self.pageControl.pageIndicatorTintColor = .systemGray
        self.pageControl.numberOfPages = orderedViewControllers.count
        self.view.addSubview(self.pageControl)

        self.pageControl.translatesAutoresizingMaskIntoConstraints = false
        self.pageControl.bottomAnchor.constraint(equalTo: self.view.bottomAnchor, constant: 5).isActive = true
        self.pageControl.widthAnchor.constraint(equalTo: self.view.widthAnchor, constant: -20).isActive = true
        self.pageControl.heightAnchor.constraint(equalToConstant: 20).isActive = true
        self.pageControl.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        notifyFreDelegate()
    }
    
    private func notifyFreDelegate() {
        freDelegate?.pageViewController(didUpdatePageIndex: self.pageControl.currentPage, count: pageControl.numberOfPages)
    }
    
    func scrollNext() {
        if self.pageControl.currentPage < self.pageControl.numberOfPages - 1 {
            scrollToViewController(index: self.pageControl.currentPage + 1)
        }
    }
    
    private func scrollToViewController(index: Int) {
        if let firstViewController = viewControllers?.first, let currentIndex = orderedViewControllers.firstIndex(of: firstViewController) {
            let direction: UIPageViewController.NavigationDirection = index >= currentIndex ? .forward : .reverse
            let nextViewController = orderedViewControllers[index]
            self.pageControl.currentPage = index
            scrollToViewController(viewController: nextViewController, direction: direction)
        }
    }
    
    
    private func scrollToViewController(viewController: UIViewController, direction: UIPageViewController.NavigationDirection = .forward) {
        setViewControllers([viewController], direction: direction, animated: true) { animationFinished -> Void in
            if animationFinished {
                self.notifyFreDelegate()
            }
        }
        
    }
    
    private static func createViewController(withIdentifier id: String) -> UIViewController {
        let stboard = UIStoryboard(name: "Main", bundle: nil)
        return stboard.instantiateViewController(withIdentifier: id)
    }
}

extension FrePageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if finished {
            if let viewController = viewControllers?.first {
                if let viewControllerIndex = self.orderedViewControllers.firstIndex(of: viewController) {
                    self.pageControl.currentPage = viewControllerIndex
                }
            }
            self.notifyFreDelegate()
        }
    }
    
    
}

extension FrePageViewController: UIPageViewControllerDataSource {
    
    func  pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.firstIndex(of: viewController) else {
            return nil
        }
        
        let previousIndex = viewControllerIndex - 1
        guard previousIndex >= 0 else {
            return nil
        }
        
        guard orderedViewControllers.count > previousIndex else {
            return nil
        }
        
        return orderedViewControllers[previousIndex]
    }
    
    func  pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
         guard let viewControllerIndex = orderedViewControllers.firstIndex(of: viewController) else {
                   return nil
               }
               
        let nextIndex = viewControllerIndex + 1
        
        guard orderedViewControllers.count != nextIndex else {
            return nil
        }
        
        guard orderedViewControllers.count > nextIndex else {
            return nil
        }
        
        return orderedViewControllers[nextIndex]
    }
    
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return orderedViewControllers.count
    }
    
    func presentationIndex(for pageViewController: UIPageViewController) -> Int {
        if let viewController = viewControllers?.first {
            return orderedViewControllers.firstIndex(of: viewController) ?? 0
        }
        return 0
    }
}
