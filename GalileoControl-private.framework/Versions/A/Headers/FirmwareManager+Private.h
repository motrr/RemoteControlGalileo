//  Created by Chris Harding on 3/21/13.
//  Copyright (c) 2013 Chris Harding. All rights reserved.
//

#import "FirmwareManager.h"

@interface FirmwareManager ()

/** Download a list of available firmware updates for a specific release group.
 @discussion The releases returned will be specific to the Galileo model currently connected to the device.
 */
- (void) getAvailableReleasesForGroup: (NSString*) releaseGroupString
                         onCompletion:(void (^)(NSArray* firmwareVersionStrings)) completionBlock;

/** Download and install a specified firmware version to the connected Galileo accessory.
 @discussion The provided release must be specific to the Galileo model currently connected to the device.
 */
- (void) downloadAndInstallRelease: (NSString*) firmwareVersionString
                      onCompletion:(void (^)(BOOL wasInstallSuccessful)) completionBlock;


@end
