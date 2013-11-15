//
//  ColorPickerViewController.m
//  ColorSample
//
//  Created by Brandon Withrow on 11/13/13.
//  Copyright (c) 2013 Brandon Withrow. All rights reserved.
//

#import "ColorPickerViewController.h"
#import "BBColorSamplerManager.h"

@interface ColorPickerViewController ()

@end

@implementation ColorPickerViewController {
  UIImageView *selectedImage_;
  UIImageView *sortedImage_;
  UIImage *theImage_;
  UIButton *selectButton_;
  UIView *backgroundColor_;
}

- (id)init {
  self = [super init];
  if (self) {
    
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor blackColor];
  backgroundColor_ = [[UIView alloc] initWithFrame:self.view.bounds];
  [self.view addSubview:backgroundColor_];
  backgroundColor_.backgroundColor = [UIColor whiteColor];
	CGSize imageSizes = self.view.bounds.size;
  imageSizes.height -= 60;
  imageSizes.height = imageSizes.height / 2;
  CGRect frame1, frame2, frame3;
  frame1.size = imageSizes;
  frame2.size = imageSizes;
  frame2.origin.y = imageSizes.height;
  frame3.size = CGSizeMake(44, 44);
  frame3.origin.x = imageSizes.width - 60;
  frame3.origin.y = CGRectGetMaxY(frame2) + 8;
  
  frame1 = CGRectInset(frame1, 20, 20);
  frame2 = CGRectInset(frame2, 20, 20);
  [[BBColorSamplerManager sharedManager] setSampleSize:frame1.size];
  selectedImage_ = [[UIImageView alloc] initWithFrame:frame1];
  selectedImage_.contentMode = UIViewContentModeScaleAspectFit;
  [self.view addSubview:selectedImage_];
  
  sortedImage_ = [[UIImageView alloc] initWithFrame:frame2];
  sortedImage_.contentMode = UIViewContentModeScaleAspectFit;
  sortedImage_.layer.shadowColor = [UIColor blackColor].CGColor;
  sortedImage_.layer.shadowOpacity = 1;
  sortedImage_.layer.shadowRadius = 3;
  sortedImage_.layer.shadowOffset = CGSizeZero;
  [self.view addSubview:sortedImage_];
  
  selectButton_ = [UIButton buttonWithType:UIButtonTypeCustom];
  [selectButton_ setImage:[UIImage imageNamed:@"listing_collections_add"] forState:UIControlStateNormal];
  [selectButton_ addTarget:self action:@selector(selectImage) forControlEvents:UIControlEventTouchUpInside];
  selectButton_.frame = frame3;
  [self.view addSubview:selectButton_];
  
}

- (void)selectImage {
  if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    UIActionSheet *selectSource = [[UIActionSheet alloc] initWithTitle:@"Select Source"
                                                              delegate:self
                                                     cancelButtonTitle:@"Cancel"
                                                destructiveButtonTitle:nil
                                                     otherButtonTitles:@"Take Photo", @"Select Photo", nil];
    [selectSource showInView:self.view];
  } else {
    [self presentImagePicker];
  }
}

- (void)presentImagePicker {
  UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
  imagePicker.delegate = self;
  
  imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
  [self presentViewController:imagePicker animated:YES completion:^{
    
  }];
}

- (void)presentCameraPicker {
  UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
  imagePicker.delegate = self;
  imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
  [self presentViewController:imagePicker animated:YES completion:^{
    
  }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
  if (buttonIndex == 0) {
    [self presentCameraPicker];
  } else if (buttonIndex == 1) {
    [self presentImagePicker];
  }
}

- (void)animateBackgroundColor:(UIColor *)newColor {
  [UIView animateWithDuration:0.4
                        delay:0.1
                      options:UIViewAnimationOptionCurveEaseInOut
                   animations:^{
                     backgroundColor_.backgroundColor = newColor;
                   } completion:^(BOOL finished) {
                   }];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
  theImage_ = [info valueForKey:UIImagePickerControllerOriginalImage];
  selectedImage_.image = theImage_;
  sortedImage_.alpha = 0;
  __weak __typeof__(self) weakSelf = self;
  [[BBColorSamplerManager sharedManager] computePrimaryColorForImage:theImage_ completionBlock:^(UIColor *color) {
    [self dismissViewControllerAnimated:YES completion:nil];
    [weakSelf animateBackgroundColor:color];
  }];
  [[BBColorSamplerManager sharedManager] sortColorForImage:theImage_ completionBlock:^(UIImage *image) {
    sortedImage_.image = image;
    [UIView animateWithDuration:0.3 animations:^{
      sortedImage_.alpha = 1;
    }];
  }];
}
@end
