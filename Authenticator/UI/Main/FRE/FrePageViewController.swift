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

  //  weak var freDelegate: FrePageViewControllerDelegate?
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        [FrePageViewController.createViewController(withIdentifier: "FreNfcViewController")]
    }()
    
    var pageControl: UIPageControl? {
        return view.subviews.first(where: { $0 is UIPageControl }) as? UIPageControl
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        delegate = self
//        dataSource = self
        
        if let initialViewController = orderedViewControllers.first {
            scrollToViewController(viewController: initialViewController)
        }
    }
    
    private func notify() {
        if let pageControl = pageControl {
//            delegate
        }
    }
    
    func scrollToViewController(index: Int) {
        
    }
    
    private func scrollToViewController(viewController: UIViewController, direction: UIPageViewController.NavigationDirection = .forward) {
        
    }
    
    private static func createViewController(withIdentifier id: String) -> UIViewController {
        let stboard = UIStoryboard(name: "Main", bundle: nil)
        return stboard.instantiateViewController(withIdentifier: id)
    }
}

extension FrePageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if finished {
            self.notify()
        }
    }
}

extension FrePageViewController: UIPageViewControllerDataSource {
    
    func  pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let viewControllerIndex = orderedViewControllers.firstIndex(of: viewController) else {
            return nil
        }
        return orderedViewControllers[viewControllerIndex - 1]
    }
    
    func  pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
         guard let viewControllerIndex = orderedViewControllers.firstIndex(of: viewController) else {
                   return nil
               }
               
         return orderedViewControllers[viewControllerIndex + 1]
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
