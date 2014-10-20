//
//  UIImage+NinePatch.h
//  ALNinePatchImage
//
//  Created by Alex Lee on 9/19/14.
//  Copyright (c) 2014 Alex Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface UIImage (NinePatch)

+ (UIImage *)ninePatchImageNamed:(NSString *)name;
+ (UIImage *)ninePatchImageWithContentsOfFile:(NSString *)path;

@end

@interface NSString (NinePatchPath)
+ (NSString *)ninePatchPathWithImageName:(NSString *)imageName;
@end
