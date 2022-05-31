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
import UIKit.UIGestureRecognizerSubclass


class MenuGestureRecognizer: UIGestureRecognizer {
    enum ButtonState {
        case touchDown
        case touchUpInside
        case dragOutside
        case dragInside
        case cancelled
    }
    
    var buttonState: ButtonState = .touchDown
    var row: UIStackView?
    var index: Int = 0
    var distanceFromMenu: CGFloat = 0
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        guard let row = self.rowFor(touch: touch) else { self.state = .cancelled; return }
        self.row = row
        self.index = (self.view?.subviews.first as? UIStackView)?.arrangedSubviews.firstIndex(of: row) ?? 0
        buttonState = .touchDown
        self.state = .began
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first else { self.state = .cancelled; return }
        if touch.isInside(in: self.view) {
            self.buttonState = .touchUpInside
            guard let row = self.rowFor(touch: touch) else { self.state = .cancelled; return }
            self.row = row
            self.index = (self.view?.subviews.first as? UIStackView)?.arrangedSubviews.firstIndex(of: row) ?? 0
            self.state = .ended
        } else {
            self.buttonState = .cancelled
            self.state = .cancelled
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { self.state = .cancelled; return }
        if touch.isInside(in: self.view) {
            self.distanceFromMenu = 0
            self.buttonState = .dragInside
            guard let row = self.rowFor(touch: touch) else { return }
            self.row = row
            self.index = (self.view?.subviews.first as? UIStackView)?.arrangedSubviews.firstIndex(of: row) ?? 0
        } else {
            self.row = nil
            self.distanceFromMenu = self.distanceFromMenu(touch: touch)
            self.buttonState = .dragOutside
        }
    }
 }

extension MenuGestureRecognizer {
    func rowFor(touch: UITouch) -> UIStackView? {
        if touch.isInside(in: self.view) {
            return (self.view?.subviews.first as? UIStackView)?.rowAt(point: touch.location(in: self.view))
        }
        return nil
    }
    
    func distanceFromMenu(touch: UITouch) -> CGFloat {
        guard let view = view else { return 0 }
        if touch.isInside(in: view) {
            return 0
        } else {
            let point = touch.location(in: self.view)
            
            let y: CGFloat
            if point.y < 0 { y = -point.y }
            else if point.y > view.frame.height { y = point.y - view.frame.height / view.transform.d }
            else { y = 0 }
            
            let x: CGFloat
            if point.x < 0 { x = -point.x }
            else if point.x > view.frame.width { x = point.x - view.frame.width / view.transform.a }
            else { x = 0 }
            return max(x, y)
        }
    }
}

extension UIStackView {
    func rowAt(point: CGPoint) -> UIStackView? {
        return arrangedSubviews.filter { $0.frame.contains(point) }.first as? UIStackView
    }
}

extension UITouch {
    func isInside(in view: UIView?) -> Bool {
        guard let view = view else { return false }
        let location = self.location(in: view)
        return location.x > 0 && location.x < view.frame.width && location.y > 0 && location.y < view.frame.height
    }
}
