/*
 * Copyright (C) Yubico.
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

import CoreNFC

/// The ways this device can connect to a YubiKey.
enum DeviceCapabilities {

    /// NFC reading of ISO 7816 tags, which YubiKeys are.
    static var supportsNFC: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return NFCTagReaderSession.readingAvailable
        #endif
    }

    /// NFC reading of NDEF tags, which is how a YubiKey sends a Yubico OTP over NFC.
    static var supportsNFCScanning: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return NFCNDEFReaderSession.readingAvailable
        #endif
    }

    /// YubiKeys connect through the Lightning port on this device.
    static var supportsLightning: Bool {
        hasLightningPort
    }

    /// YubiKeys connect as USB smart cards through the USB-C port on this device.
    static var supportsUSBC: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return !hasLightningPort
        #endif
    }

    // Every Lightning-equipped model that can install iOS/iPadOS 16 or newer, matching YubiKit.
    private static let hasLightningPort: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0) ?? ""
            }
        }

        switch model {
        case "iPhone10,1", "iPhone10,4",  // iPhone 8
            "iPhone10,2", "iPhone10,5",  // iPhone 8 Plus
            "iPhone10,3", "iPhone10,6",  // iPhone X
            "iPhone11,2",  // iPhone XS
            "iPhone11,4", "iPhone11,6",  // iPhone XS Max
            "iPhone11,8",  // iPhone XR
            "iPhone12,1",  // iPhone 11
            "iPhone12,3",  // iPhone 11 Pro
            "iPhone12,5",  // iPhone 11 Pro Max
            "iPhone12,8",  // iPhone SE (2nd generation)
            "iPhone13,1",  // iPhone 12 mini
            "iPhone13,2",  // iPhone 12
            "iPhone13,3",  // iPhone 12 Pro
            "iPhone13,4",  // iPhone 12 Pro Max
            "iPhone14,4",  // iPhone 13 mini
            "iPhone14,5",  // iPhone 13
            "iPhone14,2",  // iPhone 13 Pro
            "iPhone14,3",  // iPhone 13 Pro Max
            "iPhone14,6",  // iPhone SE (3rd generation)
            "iPhone14,7",  // iPhone 14
            "iPhone14,8",  // iPhone 14 Plus
            "iPhone15,2",  // iPhone 14 Pro
            "iPhone15,3",  // iPhone 14 Pro Max

            "iPad6,11", "iPad6,12",  // iPad (5th generation)
            "iPad7,5", "iPad7,6",  // iPad (6th generation)
            "iPad7,11", "iPad7,12",  // iPad (7th generation)
            "iPad11,6", "iPad11,7",  // iPad (8th generation)
            "iPad12,1", "iPad12,2",  // iPad (9th generation)
            "iPad11,1", "iPad11,2",  // iPad mini (5th generation)
            "iPad11,3", "iPad11,4",  // iPad Air (3rd generation)
            "iPad6,3", "iPad6,4",  // iPad Pro (9.7-inch)
            "iPad6,7", "iPad6,8",  // iPad Pro (12.9-inch, 1st generation)
            "iPad7,1", "iPad7,2",  // iPad Pro (12.9-inch, 2nd generation)
            "iPad7,3", "iPad7,4":  // iPad Pro (10.5-inch)
            return true

        default:
            return false
        }
    }()
}
