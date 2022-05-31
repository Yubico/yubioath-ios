/*
 * Copyright (C) 2022 Yubico.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *       http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit

/*
 This class is presenting UIPageController with First User Experience information about app and features on first install. It's using 3 ViewControllers that you can scroll through with options of skipping or swiping down or using NextBarButton to go to the next page. It's located in Fre.storyboard and presented modally from MainViewController using segue.
 */

class TutorialViewController: UIPageViewController {
    
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
    
    // Will use this property to manage FRE pages in the future releases.
    var userFreVersion = 0
    
    private(set) lazy var orderedViewControllers: [UIViewController] = {
        var viewControllers: [UIViewController?] = []
        
        if userFreVersion < 1 {
            viewControllers.append(self.createViewController(withIdentifier: TutorialWelcomeViewController.identifier))
            viewControllers.append(self.createViewController(withIdentifier: TutorialQRViewController.identifier))
            viewControllers.append(self.createViewController(withIdentifier: Tutorial5CiViewController.identifier))
            viewControllers.append(self.createViewController(withIdentifier: TutorialNFCViewController.identifier))
        }
        
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
    
    // When it's the last page changing 'Skip' to 'Close' and disabling 'Next'.
    private func setNavigationBar(nextViewController: UIViewController) {
        if nextViewController == orderedViewControllers.last {
            self.nextBarButton.isEnabled = false
            self.skipBarButton.title = "Close"
        } else {
            self.nextBarButton.isEnabled = true
        }
    }
    
    private func createViewController(withIdentifier id: String) -> UIViewController {
        let stboard = UIStoryboard(name: "Tutorial", bundle: nil)
        return stboard.instantiateViewController(withIdentifier: id)
    }
}

//
// MARK: - UIPageViewControllerDelegate
//

extension TutorialViewController: UIPageViewControllerDelegate {
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if finished, let currentViewController = pageViewController.viewControllers?[0] {
            setNavigationBar(nextViewController: currentViewController)
        }
    }
}

//
// MARK: - UIPageViewControllerDataSource
//

extension TutorialViewController: UIPageViewControllerDataSource {
    
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
