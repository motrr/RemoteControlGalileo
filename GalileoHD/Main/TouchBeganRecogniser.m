//  Created by Chris Harding on 04/01/2012.
//  Copyright (c) 2012 Swift Navigation. All rights reserved.
//

#import "TouchBeganRecogniser.h"

@implementation TouchBeganRecogniser

- (id) initWithTarget:(id)target action:(SEL)action
{
    if (self = [super initWithTarget:target action:action]) {
        // Setup to recognise a very short press 
        [self setAllowableMovement:99999];
        [self setMinimumPressDuration:0.0001];
    }
    return self;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer
{
    return NO;
}
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer
{
    return NO;
}

@end
