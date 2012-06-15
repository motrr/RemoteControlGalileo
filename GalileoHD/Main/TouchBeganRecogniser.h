//  Created by Chris Harding on 04/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//
//  Recognises when a view is first touched. Does not block other recognisers, and cannot itself be blocked.

#import <UIKit/UIKit.h>

typedef void (^TouchesEventBlock)(NSSet * touches, UIEvent * event);

@interface TouchBeganRecogniser : UILongPressGestureRecognizer

@end
