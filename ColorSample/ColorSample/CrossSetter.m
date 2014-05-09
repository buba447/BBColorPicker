//
//  CrossSetter.m
//  ColorSample
//
//  Created by Brandon Withrow on 11/19/13.
//  Copyright (c) 2013 Brandon Withrow. All rights reserved.
//

#import "CrossSetter.h"

@implementation CrossSetter

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
      _crossSet = 0;
    }
    return self;
}

- (void)setCrossSet:(float)crossSet {
  _crossSet = crossSet;
  
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
