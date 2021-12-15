//
//  YKFEAAccessoryManagerProtocol.h
//  Authenticator
//
//  Created by Jens Utbult on 2021-12-14.
//  Copyright © 2021 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>
//#import "EAAccessory+Testing.h"

NS_ASSUME_NONNULL_BEGIN

@protocol YKFEAAccessoryManagerProtocol<NSObject>

+ (id<YKFEAAccessoryManagerProtocol>)sharedAccessoryManager;

- (void)showBluetoothAccessoryPickerWithNameFilter:(nullable NSPredicate *)predicate completion:(nullable EABluetoothAccessoryPickerCompletion)completion;

- (void)registerForLocalNotifications;
- (void)unregisterForLocalNotifications;

@property (nonatomic, readonly) NSArray<id<YKFEAAccessoryProtocol>> *connectedAccessories;

@end

@interface EAAccessoryManager()<YKFEAAccessoryManagerProtocol>
@end

NS_ASSUME_NONNULL_END
