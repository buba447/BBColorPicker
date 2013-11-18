//
//  BBColorSamplerManager.m
//  Airbnb
//
//  Created by Brandon Withrow on 8/2/13.
//  Copyright (c) 2013 Airbnb. All rights reserved.
//

#import "BBColorSamplerManager.h"

struct bColor {
  float r;
  float g;
  float b;
  float y;
  float u;
  float v;
};

@implementation BBColorSamplerManager

- (id) init {
  if((self = [super init])) {
    _sampleSize = CGSizeMake(32, 32);
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
                   _sampleSize.height / imageSize.height : _sampleSize.width / imageSize.width);
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
      if (0.3 < y && y < 0.9 && fabs(u) > 0.05 && fabs(v) > 0.05 && s > 0.3) {
        NSMutableDictionary *newColor = [NSMutableDictionary dictionaryWithDictionary:@{@"y": @(y), @"u" : @(u), @"v" : @(v),
                                                                                        @"r" : @(red), @"g" : @(green), @"b" : @(blue)}];
        BOOL addedColor = NO;
        if (colorBuckets.count > 0) {
          for (NSMutableArray *bucket in colorBuckets) {
            //Find Distance
            NSMutableDictionary *bColor = [bucket objectAtIndex:0];
            float u2 = [[bColor objectForKey:@"u"] floatValue];
            float v2 = [[bColor objectForKey:@"v"] floatValue];
            float y2 = [[bColor objectForKey:@"y"] floatValue];
            
            float distance = sqrt(pow(u2 - u, 2) + pow(v2 - v, 2) + pow(y2 - y, 2));
            if (distance < 0.1) {
              // Weight first Average
              float count = bucket.count;
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
              
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
              
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
    UIColor *popularColor = [UIColor whiteColor];
    
    if (colorBuckets.count) {
      NSDictionary *popCol = [[colorBuckets objectAtIndex:0] objectAtIndex:0];
      for (NSArray *bucket in colorBuckets) {
        NSMutableDictionary *bColor = [bucket objectAtIndex:0];
        float u = [[bColor objectForKey:@"u"] floatValue];
        float v = [[bColor objectForKey:@"v"] floatValue];
        if (!(u < 0 && v < 0.26 && v > -0)) {
          popCol = bColor;
          break;
        }
      }
      popularColor = [UIColor colorWithRed:[[popCol objectForKey:@"r"] floatValue] green:[[popCol objectForKey:@"g"] floatValue] blue:[[popCol objectForKey:@"b"] floatValue] alpha:1];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completionBlock) {
        completionBlock(popularColor);
      }
    });
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

- (void)sortColorForImage:(UIImage *)image completionBlock:(color_sampler_sort_completion_block_t)completionBlock {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
    CGSize imageSize = image.size;
    float scale = (image.size.height > image.size.width ?
                   _sampleSize.height / imageSize.height : _sampleSize.width / imageSize.width);
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
    int finalColorCount = 0;
    NSMutableArray *colorBuckets = [NSMutableArray array];
    NSMutableArray *otherBuckets = [NSMutableArray array];
    
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
      if (0.3 < y && y < 0.9 && fabs(u) > 0.05 && fabs(v) > 0.05 && s > 0.3) {
        finalColorCount ++;
        NSMutableDictionary *newColor = [NSMutableDictionary dictionaryWithDictionary:@{@"y": @(y), @"u" : @(u), @"v" : @(v),
                                                                                        @"r" : @(red), @"g" : @(green), @"b" : @(blue)}];
        BOOL addedColor = NO;
        if (colorBuckets.count > 0) {
          for (NSMutableArray *bucket in colorBuckets) {
            //Find Distance
            NSMutableDictionary *bColor = [bucket objectAtIndex:0];
            float u2 = [[bColor objectForKey:@"u"] floatValue];
            float v2 = [[bColor objectForKey:@"v"] floatValue];
            float y2 = [[bColor objectForKey:@"y"] floatValue];
            
            float distance = sqrt(pow(u2 - u, 2) + pow(v2 - v, 2) + pow(y2 - y, 2));
            if (distance < 0.1) {
              // Weight first Average
              float count = bucket.count;
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
              
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
              
              [bucket addObject:newColor];
              addedColor = YES;
              break;
            }
          }
        }
        if (!addedColor) {
          [colorBuckets addObject:[NSMutableArray arrayWithObject:newColor]];
        }
      } else {
        //Add to 'other' bucket
        NSMutableDictionary *newColor = [NSMutableDictionary dictionaryWithDictionary:@{@"y": @(y), @"u" : @(u), @"v" : @(v),
                                                                                        @"r" : @(red), @"g" : @(green), @"b" : @(blue)}];
        BOOL addedColor = NO;
        if (otherBuckets.count > 0) {
          for (NSMutableArray *bucket in otherBuckets) {
            //Find Distance
            NSMutableDictionary *bColor = [bucket objectAtIndex:0];
            float u2 = [[bColor objectForKey:@"u"] floatValue];
            float v2 = [[bColor objectForKey:@"v"] floatValue];
            float y2 = [[bColor objectForKey:@"y"] floatValue];
            
            float distance = sqrt(pow(u2 - u, 2) + pow(v2 - v, 2) + pow(y2 - y, 2));
            if (distance < 0.1) {
              // Weight first Average
              float count = bucket.count;
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
              
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
              [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
              
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
              [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
              
              [bucket addObject:newColor];
              addedColor = YES;
              break;
            }
          }
        }
        if (!addedColor) {
          [otherBuckets addObject:[NSMutableArray arrayWithObject:newColor]];
        }
        
      }
      colorIndex += 4;
    }
    
    [colorBuckets sortUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2) {
      return obj1.count >= obj2.count ? NSOrderedAscending : NSOrderedDescending;
    }];
    [otherBuckets sortUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2) {
      return obj1.count >= obj2.count ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    //now rewrite image buffer
    int newIndex = 0;
    
    
    //Show only selected buckets
    int repeatNumber = floorf((float)count / finalColorCount);
    
    //write all of the popular colors out
    for (NSArray *buck in colorBuckets) {
      for (NSMutableDictionary *color in buck) {
        int tryTimes = 0;
        while (tryTimes < repeatNumber) {
          rawData[newIndex] = (unsigned char)([[color valueForKey:@"r"] floatValue] * 255);
          rawData[newIndex+1] = (unsigned char)([[color valueForKey:@"g"] floatValue] * 255);
          rawData[newIndex+2] = (unsigned char)([[color valueForKey:@"b"] floatValue] * 255);
          newIndex += 4;
          tryTimes ++;
        }
        
      }
    }
//    for (NSArray *buck in otherBuckets) {
//      for (NSMutableDictionary *color in buck) {
//        rawData[newIndex] = (unsigned char)([[color valueForKey:@"r"] floatValue] * 255);
//        rawData[newIndex+1] = (unsigned char)([[color valueForKey:@"g"] floatValue] * 255);
//        rawData[newIndex+2] = (unsigned char)([[color valueForKey:@"b"] floatValue] * 255);
//        newIndex += 4;
//      }
//    }

    UIColor *popularColor = [UIColor whiteColor];
    if (colorBuckets.count) {
      NSDictionary *popCol = [[colorBuckets objectAtIndex:0] objectAtIndex:0];
      for (NSArray *bucket in colorBuckets) {
        NSMutableDictionary *bColor = [bucket objectAtIndex:0];
        float u = [[bColor objectForKey:@"u"] floatValue];
        float v = [[bColor objectForKey:@"v"] floatValue];
        if (!(u < 0 && v < 0.26 && v > -0)) {
          popCol = bColor;
          break;
        }
      }
      popularColor = [UIColor colorWithRed:[[popCol objectForKey:@"r"] floatValue] green:[[popCol objectForKey:@"g"] floatValue] blue:[[popCol objectForKey:@"b"] floatValue] alpha:1];
    }
    CGRect colorRect = CGRectZero;
    colorRect.size = imageSize;
    colorRect.size.width *= 0.25;
    if (popularColor) {
      CGContextSetFillColorWithColor(context, popularColor.CGColor);
      CGContextFillRect(context, colorRect);
    }
    
    
    CGImageRef imageData = CGBitmapContextCreateImage(context);
    UIImage *returnImage = [UIImage imageWithCGImage:imageData];
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completionBlock) {
        completionBlock(returnImage);
      }
    });
  });
}

- (void)notifyNewColor:(UIColor*)color {
  [[NSNotificationCenter defaultCenter] postNotificationName:@"colorUpdated" object:nil userInfo:@{@"color" : color}];
  
}

// On Capture Queue Thread
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
  
}


- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  /*Lock the image buffer*/
  CVPixelBufferLockBaseAddress(imageBuffer,0);
  /*Get information about the image*/
  size_t width = CVPixelBufferGetWidth(imageBuffer);
  size_t height = CVPixelBufferGetHeight(imageBuffer);
  
  uint8_t* baseAddress = (uint8_t*)CVPixelBufferGetBaseAddress(imageBuffer);
  int numberOfPixels = (int)width * (int)height * 4;
  numberOfPixels = numberOfPixels / 2;
  
  NSMutableArray *colorBuckets = [NSMutableArray array];
  int i = 0;
  while (i < numberOfPixels) {
    
    float blue = (float)*(baseAddress + i) / 255.0f;
    i++;
    float green = (float)*(baseAddress + i) / 255.0f;
    i++;
    float red = (float)*(baseAddress + i) / 255.0f;
    i++;
    i++;
    i+=4;
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
    if (0.3 < y && y < 0.9 && fabs(u) > 0.05 && fabs(v) > 0.05 && s > 0.3) {
      NSMutableDictionary *newColor = [NSMutableDictionary dictionaryWithDictionary:@{@"y": @(y), @"u" : @(u), @"v" : @(v),
                                                                                      @"r" : @(red), @"g" : @(green), @"b" : @(blue)}];
      BOOL addedColor = NO;
      if (colorBuckets.count > 0) {
        for (NSMutableArray *bucket in colorBuckets) {
          //Find Distance
          NSMutableDictionary *bColor = [bucket objectAtIndex:0];
          float u2 = [[bColor objectForKey:@"u"] floatValue];
          float v2 = [[bColor objectForKey:@"v"] floatValue];
          float y2 = [[bColor objectForKey:@"y"] floatValue];
          
          float distance = sqrt(pow(u2 - u, 2) + pow(v2 - v, 2) + pow(y2 - y, 2));
          if (distance < 0.1) {
            // Weight first Average
            float count = bucket.count;
            
            [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
            [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
            [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
            
            [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
            [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
            [bColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
            [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"r"] floatValue] count:count newNumber:red]) forKey:@"r"];
            [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"g"] floatValue] count:count newNumber:green]) forKey:@"g"];
            [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"b"] floatValue] count:count newNumber:blue]) forKey:@"b"];
            
            [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"y"] floatValue] count:count newNumber:y]) forKey:@"y"];
            [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"u"] floatValue] count:count newNumber:u]) forKey:@"u"];
            [newColor setObject:@([self weightedAverage:[[bColor valueForKey:@"v"] floatValue] count:count newNumber:v]) forKey:@"v"];
            
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
  }
  [colorBuckets sortUsingComparator:^NSComparisonResult(NSArray *obj1, NSArray *obj2) {
    return obj1.count >= obj2.count ? NSOrderedAscending : NSOrderedDescending;
  }];
  
  UIColor *popularColor = [UIColor whiteColor];
  
  if (colorBuckets.count) {
    NSDictionary *popCol = [[colorBuckets objectAtIndex:0] objectAtIndex:0];
    for (NSArray *bucket in colorBuckets) {
      NSMutableDictionary *bColor = [bucket objectAtIndex:0];
      float u = [[bColor objectForKey:@"u"] floatValue];
      float v = [[bColor objectForKey:@"v"] floatValue];
      if (!(u < 0 && v < 0.26 && v > -0)) {
        popCol = bColor;
        break;
      }
    }
    popularColor = [UIColor colorWithRed:[[popCol objectForKey:@"r"] floatValue] green:[[popCol objectForKey:@"g"] floatValue] blue:[[popCol objectForKey:@"b"] floatValue] alpha:1];
  }
  

	CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self notifyNewColor:popularColor];
  });
}
@end
