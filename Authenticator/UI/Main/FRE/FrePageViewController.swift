//
//  FrePageViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

/*
 This class is presenting UIPageController with First User Experience information about app and features on first install. It's using 3 ViewControllers that you can scroll through with options of skipping or swiping down or using NextBarButton to go to the next page. It's located in Fre.storyboard and presented modally from MainViewController using segue
 */

class FrePageViewController: UIPageViewController {
    
    @IBAction func next(_ sender: Any) {
        if pageControl.currentPage == pageControl.numberOfPages - 1 {
            self.dismiss(animated: true, completion: nil)
        } else {
            scrollNext(index: pageControl.currentPage + 1)
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
    
    // invoking manually since UIPageViewController doesn't let to add pageControl to itself via storyboard because it's already there but is not visible under UIPageViewController elements hierarchy in storyboard.
    private var pageControl: UIPageControl {
        return view.subviews.first(where: { $0 is UIPageControl}) as! UIPageControl
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        
        // when view.background color is not set, part of the mainViewController is visible when present modally UIPageViewController, by default view.background is transperent.
        self.view.backgroundColor = .background
        
        setViewControllers([orderedViewControllers[0]], direction: .forward, animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // when indicator colors are not set, pageControl is not visible in light mode
        pageControl.currentPageIndicatorTintColor = .primaryText
        pageControl.pageIndicatorTintColor = .secondaryText
    }
    
    private func scrollNext(index: Int) {
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
// MARK: - UIPageViewControllerDataSource
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
