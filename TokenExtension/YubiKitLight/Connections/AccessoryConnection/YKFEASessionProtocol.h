//
//  YKFEASessionProtocol.h
//  TokenExtension
//
//  Created by Jens Utbult on 2021-12-14.
//  Copyright © 2021 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>
//#import "YKFEAccessoryProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol YKFEAAccessoryProtocol<NSObject>

@property(nonatomic, readonly, getter=isConnected) BOOL connected;
@property(nonatomic, readonly) NSUInteger connectionID;

@property(nonatomic, readonly) NSString *manufacturer;
@property(nonatomic, readonly) NSString *name;
@property(nonatomic, readonly) NSString *modelNumber;
@property(nonatomic, readonly) NSString *serialNumber;
@property(nonatomic, readonly) NSString *firmwareRevision;
@property(nonatomic, readonly) NSString *hardwareRevision;
@property(nonatomic, readonly) NSString *dockType;

@property(nonatomic, readonly) NSArray<NSString *> *protocolStrings;

@property(nonatomic, assign, nullable) id<EAAccessoryDelegate> delegate;

@end

NS_ASSUME_NONNULL_END

@interface EAAccessory()<YKFEAAccessoryProtocol>
@end


@protocol YKFEASessionProtocol<NSObject>

@property (nonatomic, readonly, nullable) id<YKFEAAccessoryProtocol> accessory;
@property (nonatomic, readonly, nullable) NSString *protocolString;
@property (nonatomic, readonly, nullable) NSInputStream *inputStream;
@property (nonatomic, readonly, nullable) NSOutputStream *outputStream;

@end

/*
 Allows to define a EASession property as id<YKFEASessionProtocol> to facilitate dependecy injection.
 */
@interface EASession()<YKFEASessionProtocol>
@end
