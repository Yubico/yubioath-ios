// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <UIKit/UIKit.h>
#import <CoreNFC/CoreNFC.h>

#import "UIDeviceAdditions.h"

#import "YubiKitDeviceCapabilities.h"
#import "YKFUIDeviceProtocol.h"

@interface YubiKitDeviceCapabilities()

@property (class, nonatomic, readonly) id<YKFUIDeviceProtocol> currentUIDevice;

@end

@implementation YubiKitDeviceCapabilities

+ (BOOL)supportsMFIAccessoryKey {

    // Simulator and USB-C type devices
    if (self.currentUIDevice.ykf_deviceModel == YKFDeviceModelSimulator ||
        self.currentUIDevice.ykf_deviceModel == YKFDeviceModelIPadPro3 ||
        self.currentUIDevice.ykf_deviceModel == YKFDeviceModelIPadPro4 ||
        self.currentUIDevice.ykf_deviceModel == YKFDeviceModelIPadAir4) {
        return NO;
    }
    if (@available(iOS 10, *)) {
        return [self systemSupportsMFIAccessoryKey];
    }
    return NO;
}

#pragma mark - Helpers

+ (id<YKFUIDeviceProtocol>)currentUIDevice {
    return UIDevice.currentDevice;
}

+ (BOOL)deviceIsNFCEnabled {
    static BOOL ykfDeviceCapabilitiesDeviceIsNFCEnabled = YES;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        YKFDeviceModel deviceModel = self.currentUIDevice.ykf_deviceModel;
        ykfDeviceCapabilitiesDeviceIsNFCEnabled =
            deviceModel == YKFDeviceModelIPhone7 || deviceModel == YKFDeviceModelIPhone7Plus ||
            deviceModel == YKFDeviceModelIPhone8 || deviceModel == YKFDeviceModelIPhone8Plus ||
            deviceModel == YKFDeviceModelIPhoneX ||
            deviceModel == YKFDeviceModelIPhoneXS || deviceModel == YKFDeviceModelIPhoneXSMax || deviceModel == YKFDeviceModelIPhoneXR ||
            deviceModel == YKFDeviceModelIPhone11 ||
            deviceModel == YKFDeviceModelIPhoneSE2 ||
            deviceModel == YKFDeviceModelUnknown; // A newer device which is not in the list yet
    });
    
    return ykfDeviceCapabilitiesDeviceIsNFCEnabled;
}

+ (BOOL)systemSupportsMFIAccessoryKey {
    static BOOL ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey = YES;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        // iOS 11.2 Versions
        NSArray *excludedVersions = @[@"11.2", @"11.2.1", @"11.2.2", @"11.2.5"];
        
        NSString *systemVersion = self.currentUIDevice.systemVersion;
        if ([excludedVersions containsObject:systemVersion]) {
            ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey = NO;
        } else {
            ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey = YES;
        }
    });
    
    return ykfDeviceCapabilitiesSystemSupportsMFIAccessoryKey;
}


@end
