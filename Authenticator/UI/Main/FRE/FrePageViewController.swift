//
//  FrePageViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

/*
 This class is presenting UIPageController with Firs User Experience information about app and feauters on first install. It's using 3 ViewControllers that you can scroll through with options of skipping or swiping down or using NextBarButton to go to the next page. It's located in Fre.storyboard and presented modally from MainViewController using segue
 */

class FrePageViewController: UIPageViewController {
    
    @IBOutlet weak var nextBarButton: UIBarButtonItem!
    @IBOutlet weak var skipBarButton: UIBarButtonItem!
    
    @IBAction func next(_ sender: Any) {
        if pageControl.currentPage == pageControl.numberOfPages {
            self.dismiss(animated: true, completion: nil)
        } else {
            self.scrollNext()
        }
    }
    
    @IBAction func skip(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        let viewControllers: [UIViewController?] = [
            self.createViewController(withIdentifier: FreWelcomeViewController.identifier),
            YubiKitDeviceCapabilities.supportsISO7816NFCTags ? self.createViewController(withIdentifier: FreNfcViewController.identifier) : nil,
            self.createViewController(withIdentifier: FreQRViewController.identifier)
        ]
        return viewControllers.compactMap { $0 }
    }()
    
    private var pageControl: UIPageControl {
        return view.subviews.first(where: { $0 is UIPageControl}) as! UIPageControl
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        dataSource = self
        
        // when view.background color is not set, part of the mainViewController is visible when present modally UIPageViewController, by default view.background is transperent.
        self.view.backgroundColor = .background
        
        if let initialViewController = orderedViewControllers.first {
            setViewControllers([initialViewController], direction: .forward, animated: true, completion: nil)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pageControl.currentPageIndicatorTintColor = .primaryText
        pageControl.pageIndicatorTintColor = .secondaryText
    }
    
    func scrollNext() {
        if pageControl.currentPage < pageControl.numberOfPages - 1 {
            scrollToViewController(index: pageControl.currentPage + 1)
        }
    }
    
    private func scrollToViewController(index: Int) {
        if let firstViewController = viewControllers?.first, let currentIndex = orderedViewControllers.firstIndex(of: firstViewController) {
            let direction: UIPageViewController.NavigationDirection = index >= currentIndex ? .forward : .reverse
            let nextViewController = orderedViewControllers[index]
            pageControl.currentPage = index
            setViewControllers([nextViewController], direction: direction, animated: true, completion: nil)
        }
    }
    
    private func createViewController(withIdentifier id: String) -> UIViewController {
        let stboard = UIStoryboard(name: "Fre", bundle: nil)
        return stboard.instantiateViewController(withIdentifier: id)
    }
}

//
// MARK: - UIPageViewControllerDelegate
//

extension FrePageViewController: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if finished {
            if let viewController = viewControllers?.first {
                if let viewControllerIndex = self.orderedViewControllers.firstIndex(of: viewController) {
                    pageControl.currentPage = viewControllerIndex
                }
            }
        }
    }
}

//
// MARK: - UIPageViewControllerDelegate
//

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
