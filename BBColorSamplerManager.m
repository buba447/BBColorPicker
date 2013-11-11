//
//  BBColorSamplerManager.m
//  Airbnb
//
//  Created by Brandon Withrow on 8/2/13.
//  Copyright (c) 2013 Airbnb. All rights reserved.
//

#import "BBColorSamplerManager.h"

@implementation BBColorSamplerManager

- (id) init {
  if((self = [super init])) {
  }
  return self;
}

+ (BBColorSamplerManager *)sharedManager {
  static BBColorSamplerManager *sharedManager = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedManager = [[[self class] alloc] init];
  });
  return sharedManager;
}

- (void)computePrimaryColorForImage:(UIImage *)image completionBlock:(color_sampler_completion_block_t)completionBlock {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    CGSize imageSize = image.size;
    float scale = (image.size.height > image.size.width ?
                   32 / imageSize.height : 32 / imageSize.width);
    if (scale < 1) {
      imageSize.width = roundf(imageSize.width * scale);
      imageSize.height = roundf(imageSize.height * scale);
    }
    CGRect drawingRect = CGRectMake(0, 0, imageSize.width, imageSize.height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  
    
    unsigned char *rawData =
        (unsigned char*) calloc(imageSize.height * imageSize.width * 4, sizeof(unsigned char));
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * imageSize.width;
    NSUInteger bitsPerComponent = 8;
    
    CGContextRef context = CGBitmapContextCreate(rawData, imageSize.width, imageSize.height,
                                                 bitsPerComponent, bytesPerRow, colorSpace,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, drawingRect, image.CGImage);
    
    int count = (imageSize.width * imageSize.height);
    int colorIndex = 0;
    NSMutableArray *colorBuckets = [NSMutableArray array];
    
    for (int i = 0 ; i < count ; ++i) {
      float red = ((float)rawData[colorIndex] * 1.0f) / 255.0f;
      float green = ((float)rawData[colorIndex+1] * 1.0f) / 255.0f;
      float blue = ((float)rawData[colorIndex+2] * 1.0f) / 255.0f;
      
      // Convert to Y for brightness.
      float y = 0.299 * red + 0.587 * green + 0.114 * blue;
      float u = -0.14713 * red - 0.28886 * green + 0.436 * blue;
      float v = 0.615 * red - 0.51499 * green - 0.10001 * blue;
      
      double min, max, delta, s;
      
      min = red < green ? red : green;
      min = min  < blue ? min  : blue;
      
      max = red > green ? red : green;
      max = max  > blue ? max  : blue;
      
      delta = max - min;
      if( max > 0.0 )
        s = (delta / max);
      else
        s = 0;
      
      //Check if valid color brightness
      if (0.3 < y && y < 0.9 && fabs(u) > 0.05 && fabs(v) > 0.05 && s > 0.4) {

        NSMutableDictionary *newColor = [NSMutableDictionary dictionaryWithDictionary:@{@"y": @(y), @"u" : @(u), @"v" : @(v),
                                                                                        @"r" : @(red), @"g" : @(green), @"b" : @(blue)}];
        BOOL addedColor = NO;
        if (colorBuckets.count > 0) {
          for (NSMutableArray *bucket in colorBuckets) {
            //Find Distance
            NSMutableDictionary *bColor = [bucket objectAtIndex:0];
            float u2 = [[bColor objectForKey:@"u"] floatValue];
            float v2 = [[bColor objectForKey:@"v"] floatValue];

            float distance = sqrt(pow(u2 - u, 2) + pow(v2 - v, 2));
            if (distance < 0.05) {
              // Weight first Average
              float count = bucket.count;
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
              
              [bucket addObject:newColor];
              addedColor = YES;
              break;
            }
          }
        }
        if (!addedColor) {
          [colorBuckets addObject:[NSMutableArray arrayWithObject:newColor]];
        }
      }
      colorIndex += 4;
    }
    [colorBuckets sortUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2) {
      return obj1.count >= obj2.count ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    UIColor *popularColor = nil;
    if (colorBuckets.count) {
      NSDictionary *popCol = [[colorBuckets objectAtIndex:colorBuckets.count > 1 ? 1 : 0] objectAtIndex:0];
      popularColor = [UIColor colorWithRed:[[popCol objectForKey:@"r"] floatValue] green:[[popCol objectForKey:@"g"] floatValue] blue:[[popCol objectForKey:@"b"] floatValue] alpha:1];
      
      dispatch_async(dispatch_get_main_queue(), ^{
        if (completionBlock) {
          completionBlock(popularColor);
        }
      });
    }
  });
  
  }

- (float)weightedAverage:(float)baseAverage count:(float)count newNumber:(float)newNumber {
  return ((baseAverage * count) + newNumber) / (count + 1);
}

- (void)colorFound:(UIColor *)color forKey:(NSString *)key {
  [[NSNotificationCenter defaultCenter] postNotificationName:kBBColorSamplerDidFindColorNotification
                                                      object:self
                                                    userInfo:@{@"color" : color,
                                                                @"colorKey" : key}];
}

@end
