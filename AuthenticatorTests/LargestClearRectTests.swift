/*
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

import CoreGraphics
import Testing
@testable import Authenticator

struct LargestClearRectTests {

    let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)

    @Test func noObstaclesKeepsBounds() {
        #expect(bounds.largestClearRect(avoiding: []) == bounds)
    }

    @Test func obstacleOutsideBoundsIsIgnored() {
        let obstacle = CGRect(x: 500, y: 0, width: 50, height: 50)
        #expect(bounds.largestClearRect(avoiding: [obstacle]) == bounds)
    }

    @Test func horizontalFoldPicksLargerHalf() {
        // A fold across the screen slightly above the middle leaves the bottom half larger.
        let fold = CGRect(x: 0, y: 380, width: 400, height: 20)
        #expect(bounds.largestClearRect(avoiding: [fold]) == CGRect(x: 0, y: 400, width: 400, height: 400))
    }

    @Test func verticalFoldPicksLargerHalf() {
        let landscape = CGRect(x: 0, y: 0, width: 800, height: 400)
        let fold = CGRect(x: 390, y: 0, width: 20, height: 400)
        #expect(landscape.largestClearRect(avoiding: [fold]) == CGRect(x: 0, y: 0, width: 390, height: 400))
    }

    @Test func cameraHousingPrefersShorterSideOverArea() {
        // A housing in the top corner: the strip beside it is tall but narrow, the part below it is wider.
        let housing = CGRect(x: 0, y: 0, width: 300, height: 100)
        #expect(bounds.largestClearRect(avoiding: [housing]) == CGRect(x: 0, y: 100, width: 400, height: 700))
    }

    @Test func foldAndHousingTogether() {
        let fold = CGRect(x: 0, y: 390, width: 400, height: 20)
        let housing = CGRect(x: 150, y: 410, width: 100, height: 40)
        // The top half is untouched by the housing, so it beats the bottom half.
        #expect(bounds.largestClearRect(avoiding: [fold, housing]) == CGRect(x: 0, y: 0, width: 400, height: 390))
    }

    @Test func obstacleCoveringBoundsKeepsBounds() {
        #expect(bounds.largestClearRect(avoiding: [bounds.insetBy(dx: -10, dy: -10)]) == bounds)
    }
}
