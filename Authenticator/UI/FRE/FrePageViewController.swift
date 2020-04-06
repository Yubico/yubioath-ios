//
//  FrePageViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

/*
 This class is presenting UIPageController with First User Experience information about app and features on first install. It's using 3 ViewControllers that you can scroll through with options of skipping or swiping down or using NextBarButton to go to the next page. It's located in Fre.storyboard and presented modally from MainViewController using segue.
 */

class FrePageViewController: UIPageViewController {
    
    @IBOutlet weak var nextBarButton: UIBarButtonItem!
    @IBOutlet weak var skipBarButton: UIBarButtonItem!
    
    @IBAction func next(_ sender: Any) {
        if let currentViewController = viewControllers?[0], let nextViewController = pageViewController(self, viewControllerAfter: currentViewController) {
            setNavigationBar(nextViewController: nextViewController)
            setViewControllers([nextViewController], direction: .forward, animated: true, completion: nil)
        }
    }
    
    @IBAction func skip(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        var viewControllers: [UIViewController?] = []
        viewControllers.append(self.createViewController(withIdentifier: FreWelcomeViewController.identifier))
        viewControllers.append(self.createViewController(withIdentifier: Fre5CiViewController.identifier))
        viewControllers.append(YubiKitDeviceCapabilities.supportsISO7816NFCTags ? self.createViewController(withIdentifier: FreNfcViewController.identifier) : nil)
        viewControllers.append(self.createViewController(withIdentifier: FreQRViewController.identifier))
        viewControllers.append(self.createViewController(withIdentifier: FreFavoritesViewController.identifier))
        
        return viewControllers.compactMap { $0 }
    }()
    
    // Invoking manually since UIPageViewController doesn't let to add pageControl
    // to itself via storyboard because it's already there but is not visible under
    // UIPageViewController elements hierarchy in storyboard.
    private var pageControl: UIPageControl {
        return view.subviews.first(where: { $0 is UIPageControl}) as! UIPageControl
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        dataSource = self
        SettingsConfig.lastFreVersionShown = .freVersion
        // When view.background color is not set, part of the mainViewController is
        // visible when present modally UIPageViewController, by default
        // view.background is transperent.
        self.view.backgroundColor = .background

        setViewControllers([orderedViewControllers[0]], direction: .forward, animated: true, completion: nil)
        setNavigationBar(nextViewController: orderedViewControllers[0])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // when indicator colors are not set, pageControl is not visible in light mode
        pageControl.currentPageIndicatorTintColor = .yubiBlue
        pageControl.pageIndicatorTintColor = .secondaryText
    }
    
    // When it's the last page changing 'Skip' to 'Done' and disabling 'Next'.
    private func setNavigationBar(nextViewController: UIViewController) {
        if nextViewController == orderedViewControllers.last {
            self.nextBarButton.isEnabled = false
            self.skipBarButton.title = "Done"
        } else {
            self.nextBarButton.isEnabled = true
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
        if finished, let currentViewController = pageViewController.viewControllers?[0] {
            setNavigationBar(nextViewController: currentViewController)
        }
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
