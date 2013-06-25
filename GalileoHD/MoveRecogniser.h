//  Created by Chris Harding on 03/01/2012.
//  Copyright (c) 2012 motrr, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MoveRecogniser : UIGestureRecognizer

- (CGPoint)translationInView:(UIView *)view;
- (CGPoint)velocityInView:(UIView *)view;

@property (nonatomic) NSUInteger maximumNumberOfTouches;
@property (nonatomic) NSUInteger minimumNumberOfTouches;

@end