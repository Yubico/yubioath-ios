//
//  WebViewController.swift
//  Authenticator
//
//  Created by Irina Rakhmanova on 11/11/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController, WKUIDelegate {

    @IBOutlet var webView: WKWebView!
    
    // Using property insead of IBOutlet, because outlet is nil for some reason after inithialization and
    // compiler throughs 'Fatal error: unecxpectedly found nil...' error message.
    private var activityIndicator: UIActivityIndicatorView!
    
    var url: URL?
    
    override func loadView() {
        let webConfig = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.uiDelegate = self
        // Assigning webView to view since phone reboots when using view.addSubview(webView).
        view = webView
    }
    
    // Setting up the activity indicator in ViewWillAppear before the view hierarchy is loaded into memory.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        activityIndicator.center = webView.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = .gray
        webView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let url = self.url {
            webView.load(URLRequest(url: url))
        }
        
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
    }
}

// MARK: - WebKitNavigationDelegate

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
    }
}
