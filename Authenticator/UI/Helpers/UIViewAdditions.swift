/*
 * Copyright (C) 2022 Yubico.
 * Copyright (C) 2026 Kenzi Voyer.
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

@propertyWrapper
public struct UsesAutoLayout<T: UIView> {
    public var wrappedValue: T {
        didSet {
            wrappedValue.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
        wrappedValue.translatesAutoresizingMaskIntoConstraints = false
    }
}

extension CGRect {
    // The largest part of the rect that none of the obstacles overlap. Pieces are ranked by their shorter side
    // first, so centered content like a square scan frame or a row of digits gets the most usable space.
    func largestClearRect(avoiding obstacles: [CGRect]) -> CGRect {
        var candidates = [self]
        for obstacle in obstacles where obstacle.intersects(self) {
            candidates = candidates.flatMap { candidate -> [CGRect] in
                guard candidate.intersects(obstacle) else { return [candidate] }
                return [
                    CGRect(x: candidate.minX, y: candidate.minY, width: obstacle.minX - candidate.minX, height: candidate.height),
                    CGRect(x: obstacle.maxX, y: candidate.minY, width: candidate.maxX - obstacle.maxX, height: candidate.height),
                    CGRect(x: candidate.minX, y: candidate.minY, width: candidate.width, height: obstacle.minY - candidate.minY),
                    CGRect(x: candidate.minX, y: obstacle.maxY, width: candidate.width, height: candidate.maxY - obstacle.maxY)
                ].filter { $0.width > 0 && $0.height > 0 }
            }
        }
        return candidates.max { a, b in
            (min(a.width, a.height), a.width * a.height) < (min(b.width, b.height), b.width * b.height)
        } ?? self
    }
}

extension UIView {
    // The largest part of the bounds that the fold and the camera housing leave clear, on devices that reserve regions.
    var boundsClearOfReservedRegions: CGRect {
        guard #available(iOS 27.1, *) else { return bounds }
        let regions = reservedRegions(kind: .division) + reservedRegions(kind: .occlusion)
        return bounds.largestClearRect(avoiding: regions.map(\.frame))
    }
}
