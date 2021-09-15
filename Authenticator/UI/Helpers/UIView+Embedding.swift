//
//  UIView+Embedding.swift
//  Form
//
//  Created by Måns Bernhardt on 2015-09-17.
//  Copyright © 2015 PayPal Inc. All rights reserved.
//  https://github.com/iZettle/Form
//  MIT License
//

import UIKit

public extension UIView {
    /// Adds view as a subview to `self` and sets up constraints according to passed parameters.
    /// - Parameters:
    ///   - view: View to embed
    ///   - layoutArea: Area to guide layout, defaults to `.default`.
    ///   - edgeInsets: Insets from `self`, defaults to `.zero`.
    ///   - pinToEdges:  Edges to pin `view` to, defaults to `.all` If pinning is missing for one axis the view will be centered in that axis.
    ///   - layoutPriority: The priority to apply to all added constraints, defaults to `.required`
    func embedView(_ view: UIView, edgeInsets: UIEdgeInsets = UIEdgeInsets.zero, pinToEdges: UIRectEdge = .all, layoutPriority: UILayoutPriority = .required) {
        let insets = edgeInsets
        if pinToEdges == .all {
            view.frame = bounds.inset(by: insets) // preset the frame to avoid an unnecessary relayout and unwanted animations
        }

        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)

        var constraints = [NSLayoutConstraint]()

        if pinToEdges.intersection([.left, .right]).isEmpty { // Center X, adjusting for horizontal insets
            let centerXConstraint = self.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: insets.left - insets.right)
            let widthConstraint = view.widthAnchor.constraint(lessThanOrEqualTo: self.widthAnchor, constant: -(insets.left + insets.right))
            constraints += [centerXConstraint, widthConstraint]

        } else {
            if pinToEdges.contains(.left) {
                constraints.append(view.leftAnchor.constraint(equalTo: self.leftAnchor, constant: insets.left))
            } else if pinToEdges.contains(.right) {
                constraints.append(view.leftAnchor.constraint(greaterThanOrEqualTo: self.leftAnchor, constant: insets.left))
            }

            if pinToEdges.contains(.right) {
                constraints.append(self.rightAnchor.constraint(equalTo: view.rightAnchor, constant: insets.right))
            } else if pinToEdges.contains(.left) {
                constraints.append(self.rightAnchor.constraint(greaterThanOrEqualTo: view.rightAnchor, constant: insets.right))
            }
        }

        if pinToEdges.intersection([.top, .bottom]).isEmpty { // Center Y, adjusting for vertical insets
            let centerYConstraint = view.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: insets.top - insets.bottom)
            let heightConstraint = view.heightAnchor.constraint(lessThanOrEqualTo: self.heightAnchor, constant: -(insets.top + insets.bottom))
            constraints += [centerYConstraint, heightConstraint]
        } else {
            if pinToEdges.contains(.top) {
                constraints.append(view.topAnchor.constraint(equalTo: self.topAnchor, constant: insets.top))
            } else if pinToEdges.contains(.bottom) {
                constraints.append(view.topAnchor.constraint(greaterThanOrEqualTo: self.topAnchor, constant: insets.top))
            }

            if pinToEdges.contains(.bottom) {
                constraints.append(self.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: insets.bottom))
            } else if pinToEdges.contains(.top) {
                constraints.append(self.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor, constant: insets.bottom))
            }
        }

        constraints.forEach { $0.priority = layoutPriority }
        NSLayoutConstraint.activate(constraints)
    }
}

public extension UIScrollView {
    /// Adds view as a subview to `self` and sets up constraints for the `scrollAxis`.
    func embedView(_ view: UIView, scrollAxis: NSLayoutConstraint.Axis) {
        addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([self.topAnchor.constraint(equalTo: view.topAnchor),
                                     self.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                                     self.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                     self.trailingAnchor.constraint(equalTo: view.trailingAnchor)]
        )

        switch scrollAxis {
        case .horizontal:
            NSLayoutConstraint.activate([self.heightAnchor.constraint(equalTo: view.heightAnchor)])
        case .vertical:
            NSLayoutConstraint.activate([self.widthAnchor.constraint(equalTo: view.widthAnchor)])
        @unknown default:
            assertionFailure("Unknown ScrollAxis")
        }
    }
}

public extension UIView {
    /// Adds view as a subview to `self` and sets up autoresizingMask according to passed parameters.
    /// - Parameter view: View to embed
    /// - Parameter edgeInsets: Insets from `self`, defaults to `.zero`.
    /// - Parameter pinToEdges:  Edges to pin `view` to, defaults to `.all` If pinning is missing for one axis the view will be centered in that axis.
    func embedAutoresizingView(_ view: UIView, edgeInsets: UIEdgeInsets = UIEdgeInsets.zero, pinToEdges: UIRectEdge = .all) {
        var autoresizingMask: UIView.AutoresizingMask = []

        if pinToEdges.contains([ .left, .right]) {
            view.frame.origin.x = edgeInsets.left
            view.frame.size.width = bounds.size.width - edgeInsets.left - edgeInsets.right
            autoresizingMask.formUnion(.flexibleWidth)
        } else if pinToEdges.contains(.left) {
            view.frame.origin.x = edgeInsets.left
        } else if pinToEdges.contains(.right) {
            view.frame.origin.x = bounds.size.width - edgeInsets.right - view.bounds.size.width
        }

        if pinToEdges.contains([ .top, .bottom]) {
            view.frame.origin.y = edgeInsets.top
            view.frame.size.height = bounds.size.height - edgeInsets.top - edgeInsets.bottom
            autoresizingMask.formUnion(.flexibleHeight)
        } else if pinToEdges.contains(.top) {
            view.frame.origin.y = edgeInsets.top
        } else if pinToEdges.contains(.bottom) {
            view.frame.origin.y = bounds.size.height - edgeInsets.bottom - view.bounds.size.height
        }

        if !pinToEdges.contains(.left) {
            autoresizingMask.formUnion(.flexibleLeftMargin)
        }

        if !pinToEdges.contains(.right) {
            autoresizingMask.formUnion(.flexibleRightMargin)
        }

        if !pinToEdges.contains(.top) {
            autoresizingMask.formUnion(.flexibleTopMargin)
        }

        if !pinToEdges.contains(.bottom) {
            autoresizingMask.formUnion(.flexibleBottomMargin)
        }

        view.autoresizingMask = autoresizingMask
        addSubview(view)
    }
}
