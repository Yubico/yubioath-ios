//
//  PieProgressBar.swift
//  Authenticator
//
//  Created by Irina Makhalova on 7/26/19.
//  Copyright © 2019 Irina Makhalova. All rights reserved.
//

import UIKit

/*! View that shows progress bar in each credential cell showing how much time left before expiration
 * It uses UIBezierPath on CAShapeLayer to draw the circle
 */
class PieProgressBar: UIView {

    //MARK: awakeFromNib
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    //MARK: Public
    
    public func setProgress(to progressConstant: Double) {
        var progress: Double {
            get {
                if progressConstant > 1 { return 1 }
                else if progressConstant < 0 { return 0 }
                else { return progressConstant }
            }
        }
        shapeLayer.fillColor = self.tintColor.cgColor
        self.shapeLayer.path = getArchPath(progress: CGFloat(progress))
    }
    
    //MARK: Private

    private let shapeLayer = CAShapeLayer()
    private var radius: CGFloat {
        get{
            if self.frame.width < self.frame.height { return self.frame.width / 2.5 }
            else { return self.frame.height / 2.5 }
        }
    }
    
    private var pathCenter: CGPoint{ get{ return self.convert(self.center, from:self.superview) } }
    
    private func getArchPath(progress: CGFloat) -> CGPath {
        let startAngle = (-CGFloat.pi/2)
        let endAngle = startAngle + 2 * CGFloat.pi

        let path = UIBezierPath(arcCenter: self.pathCenter, radius: self.radius, startAngle: startAngle + (1 - progress)
        * 2 * CGFloat.pi, endAngle:endAngle, clockwise: true)
        path.addLine(to: pathCenter)
        return path.cgPath
    }
    
    func setupView() {
        self.layer.sublayers = nil

        shapeLayer.path = getArchPath(progress: 1)
        shapeLayer.fillColor = self.tintColor.cgColor
        self.layer.addSublayer(shapeLayer)
    }
}
