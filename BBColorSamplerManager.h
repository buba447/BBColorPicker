//
//  BBColorSamplerManager.h
//  Airbnb
//
//  Created by Brandon Withrow on 8/2/13.
//  Copyright (c) 2013 Airbnb. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kBBColorSamplerDidFindColorNotification @"BBColorSamplerDidFindColor"

typedef void (^color_sampler_completion_block_t)(UIColor *);

@interface BBColorSamplerManager : NSObject

- (void)computePrimaryColorForImage:(UIImage *)image completionBlock:(color_sampler_completion_block_t)completionBlock;

+ (BBColorSamplerManager *)sharedManager;

@end
