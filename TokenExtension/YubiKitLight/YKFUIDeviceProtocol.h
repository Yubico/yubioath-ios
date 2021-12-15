//
//  DeviceCapabilities.h
//  Authenticator
//
//  Created by Jens Utbult on 2021-12-14.
//  Copyright © 2021 Yubico. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIDeviceAdditions.h"

@protocol YKFUIDeviceProtocol <NSObject>

@property (nonatomic) NSString  *systemVersion;
@property (nonatomic) YKFDeviceModel ykf_deviceModel;

@end

@interface UIDevice()<YKFUIDeviceProtocol>
@end
