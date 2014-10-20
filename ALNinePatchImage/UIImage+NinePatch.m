//
//  UIImage+NinePatch.m
//  ALNinePatchImage
//
//  Created by Alex Lee on 9/19/14.
//  Copyright (c) 2014 Alex Lee. All rights reserved.
//

#import "UIImage+NinePatch.h"


#define isEmptyString(s)  (((s) == nil) || ([(s) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0))
#define ALRangeNotFound NSMakeRange(NSNotFound, 0)
#define NSNullToNil(o) ((o) == [NSNull null] ? nil : (o))
#define UNNilString(str) ((str) == nil ? @"" : (str))
#if DEBUG
    #define ALLog(fmt, ...) NSLog((@"[ALNinePatchImage] %s(Line:%d) " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
    #define ALLog(fmt, ...) do{}while(0)
#endif

static int kBytesPerPixel       = 4;
static int kBitsPerComponent    = 8;

static NSString * const CacheInfoPlist = @"9_patch_images.plist";
static NSString * const CachedInfoCachedPathKey     = @"cached_path";
static NSString * const CacheInfoCapsKey            = @"CapInsets";
static NSString * const CacheInfoCapsTopKey         = @"top";
static NSString * const CacheInfoCapsLeftKey        = @"left";
static NSString * const CacheInfoCapsBottomKey      = @"bottom";
static NSString * const CacheInfoCapsRightKey       = @"right";

static NSString * const HomePathVar     = @"$HOME";
static NSString * const BundlePathVar   = @"$BUNDLE";

@implementation UIImage(NinePatch)

static NSMutableDictionary *NinePatchImageCache = nil;
static NSMutableDictionary *CachedImagesInfo    = nil;
static dispatch_queue_t    CachedWriterQueue    = nil;

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CachedWriterQueue = dispatch_queue_create([@"9patch_image_cached_queue" UTF8String], NULL);
        NinePatchImageCache = [NSMutableDictionary dictionary];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    });
}

#pragma mark - public
+ (UIImage *)ninePatchImageNamed:(NSString *)name
{
    UIImage *img = [self _cachedNinePatchImageForName:name];
    if (!img) {
        img = [self _ninePatchImageNamed:name];
        [self _cacheNinePatchImage:img forName:name];
    }
    return img;
}

+ (UIImage *)ninePatchImageWithContentsOfFile:(NSString *)path
{
    NSString *cachedPath = [self cachedKeyForImageWithPath:path];
    NSDictionary *cacheInfo = [self cacheInfoForImageWithPath:cachedPath];
    if ([self isValidCachedItemforKey:cachedPath]) {
        cachedPath = [[self cacheDirectory] stringByAppendingPathComponent:UNNilString(NSNullToNil(cacheInfo[CachedInfoCachedPathKey]))];
        UIImage *image = [self imageWithContentsOfFile:cachedPath];
        NSDictionary *capsDic = NSNullToNil(cacheInfo[CacheInfoCapsKey]);
        UIEdgeInsets caps = UIEdgeInsetsMake([NSNullToNil(capsDic[CacheInfoCapsTopKey]) floatValue],
                                             [NSNullToNil(capsDic[CacheInfoCapsLeftKey]) floatValue],
                                             [NSNullToNil(capsDic[CacheInfoCapsBottomKey]) floatValue],
                                             [NSNullToNil(capsDic[CacheInfoCapsRightKey]) floatValue]);
        if ([image respondsToSelector:@selector(resizableImageWithCapInsets:)]) {
            return [image resizableImageWithCapInsets:caps];
        } else {
            return [image stretchableImageWithLeftCapWidth:caps.left topCapHeight:caps.top];
        }
    }
    return [self _ninePatchImageWithContentsOfFile:path];
}


- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
    @synchronized([self class]) {
        [NinePatchImageCache removeAllObjects];
        [CachedImagesInfo removeAllObjects];
        CachedImagesInfo = nil;
    }
}

#pragma mark - private: cached
+ (UIImage *)_ninePatchImageNamed:(NSString *)name
{
    NSString *path = [NSString ninePatchPathWithImageName:name];
    UIImage *img = [self ninePatchImageWithContentsOfFile:path];
    
    return img;
}

+ (UIImage *)_ninePatchImageWithContentsOfFile:(NSString *)path
{
    UIImage *origImg = [UIImage imageWithContentsOfFile:path];
    if (origImg == nil) {
        return nil;
    }
    NSUInteger w = origImg.size.width;
    NSUInteger h = origImg.size.height;
    
    CGFloat clipWidth   = 1.f / origImg.scale;
    UIImage *topImg     = [origImg clipImageAtRect:CGRectMake(clipWidth, 0.0f, w - 2 * clipWidth, clipWidth)];
    UIImage *leftImg    = [origImg clipImageAtRect:CGRectMake(0.0f, clipWidth, clipWidth,     h - 2 * clipWidth)];
    UIImage *centerImg  = [origImg clipImageAtRect:CGRectMake(clipWidth, clipWidth, w - 2 * clipWidth, h - 2 * clipWidth)];
    ALLog(@"%@, origin image size:[%f, %f]; center image size:[%f, %f], scale:%f", path, (CGFloat)w, (CGFloat)h, centerImg.size.width, centerImg.size.height, centerImg.scale);
    
    NSRange horizontalStrentchRange = [topImg rangeOfBlackPiexlsWithOrientation:NO];
    NSRange verticalStrentchRange   = [leftImg rangeOfBlackPiexlsWithOrientation:YES];
    
    NSUInteger leftCap = horizontalStrentchRange.location;
    NSUInteger topCap  = verticalStrentchRange.location;
    leftCap = leftCap == NSNotFound ? 0 : leftCap;
    topCap  = topCap == NSNotFound  ? 0 : topCap;
    
    CGSize imageSize = centerImg.size;
    NSUInteger rightCap = 0;
    if (horizontalStrentchRange.length > 0) {
        rightCap = imageSize.width - leftCap - horizontalStrentchRange.length;
    }
    NSUInteger bottomCap = 0;
    if (verticalStrentchRange.length > 0) {
        bottomCap = imageSize.height - topCap - verticalStrentchRange.length;
    }
    UIEdgeInsets capsInsets = UIEdgeInsetsMake(topCap, leftCap, bottomCap, rightCap);
    NSString *cacheInfoFile = [[self cacheDirectory] stringByAppendingPathComponent:CacheInfoPlist];
    NSString *cacheKey = [self cachedKeyForImageWithPath:path];
    NSString *pathExtension = [path.pathExtension.lowercaseString isEqualToString:@"jpg"] ? @"jpg" : @"png";
    NSString *cacheImageFile = [[self UUIDString] stringByAppendingFormat:@"@%zdx.%@", (NSInteger)centerImg.scale, pathExtension];
    dispatch_async(CachedWriterQueue, ^{
        CachedImagesInfo[cacheKey] = @{CachedInfoCachedPathKey: cacheImageFile == nil ? [NSNull null] : cacheImageFile,
                                       CacheInfoCapsKey: @{CacheInfoCapsTopKey:     @(topCap),
                                                           CacheInfoCapsLeftKey:    @(leftCap),
                                                           CacheInfoCapsBottomKey:  @(bottomCap),
                                                           CacheInfoCapsRightKey:   @(rightCap)
                                                           }
                                       };
        NSDictionary *cacheDic = [NSDictionary dictionaryWithDictionary:CachedImagesInfo];
        if (![cacheDic writeToFile:cacheInfoFile atomically:YES]) {
            ALLog(@"[ERROR] can not write to file '%@'", cacheInfoFile);
        }

        NSString *cacheImagePath = [[self cacheDirectory] stringByAppendingPathComponent:cacheImageFile];
        if ([pathExtension isEqualToString:@"jpg"]) {
            [UIImageJPEGRepresentation(centerImg, 1.f) writeToFile:cacheImagePath atomically:YES];
        } else {
            [UIImagePNGRepresentation(centerImg) writeToFile:cacheImagePath atomically:YES];
        }
    });
    
    if ([centerImg respondsToSelector:@selector(resizableImageWithCapInsets:)]) {
        return [centerImg resizableImageWithCapInsets:capsInsets];
    } else {
        return [centerImg stretchableImageWithLeftCapWidth:leftCap topCapHeight:topCap];
    }
}

+ (UIImage *)_cachedNinePatchImageForName:(NSString *)name
{
    return NinePatchImageCache[name];
}

+ (void)_cacheNinePatchImage:(UIImage *)image forName:(NSString *)name
{
    if (image && name) {
        @synchronized(self){
            NinePatchImageCache[name] = image;
        }
    }
}


#pragma mark - private: nine patch
- (NSRange)rangeOfBlackPiexlsWithOrientation:(BOOL)vertical
{
    NSRange blackPixelRange = ALRangeNotFound;
    CGSize imageSize = (CGSize){.width = self.size.width * self.scale, .height = self.size.height * self.scale};
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSUInteger bitmapLength = imageSize.width * imageSize.height * kBytesPerPixel;
    UInt8 *bitmap = (UInt8 *)malloc(bitmapLength);
    memset(bitmap, 0x00, bitmapLength);
    
    NSUInteger bytesPerRow = kBytesPerPixel * imageSize.width;
    
    CGContextRef context = CGBitmapContextCreate(bitmap, imageSize.width, imageSize.height, kBitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, imageSize.width, imageSize.height), self.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    if (vertical) {
        //V stretch
        for (NSUInteger vIndex = 0; vIndex < imageSize.height; ++ vIndex) {
            NSUInteger offset = (vIndex * imageSize.width + 0) * kBytesPerPixel;
            if (bitmap[offset]    /* red */    == 0 &&
                bitmap[offset + 1]/* green */  == 0 &&
                bitmap[offset + 2]/* blue */   == 0 &&
                bitmap[offset + 3]/* alpha */  == 0xff) {
                if (NSNotFound == blackPixelRange.location) {
                    blackPixelRange.location = vIndex;
                }
                ++ blackPixelRange.length;
            } else {
                if (NSNotFound != blackPixelRange.location) {
                    break;
                }
            }
        }
    } else {
        for (NSUInteger hIndex = 0; hIndex < imageSize.width; ++ hIndex) {
            NSUInteger offset = hIndex * kBytesPerPixel;
            ALLog(@"pixel[%zd]:[%zd, %zd, %zd, %zd]", offset, bitmap[offset], bitmap[offset + 1], bitmap[offset + 2], bitmap[offset + 3]);
            if (bitmap[offset]     /* red */   == 0 &&
                bitmap[offset + 1] /* green */ == 0 &&
                bitmap[offset + 2] /* blue */  == 0 &&
                bitmap[offset + 3] /* alpha */ == 0xff) {
                if (NSNotFound == blackPixelRange.location) {
                    blackPixelRange.location = hIndex;
                }
                ++ blackPixelRange.length;
            } else {
                if (NSNotFound != blackPixelRange.location) {
                    break;
                }
            }
        }
    }
    free(bitmap);
    
    if (blackPixelRange.location != NSNotFound) {
        blackPixelRange.location /= self.scale;
    }
    blackPixelRange.length   /= self.scale;
    
    return blackPixelRange;
}


- (UIImage *)clipImageAtRect:(CGRect)rect
{
    UIImage *subImage = nil;
    CGImageRef cir = [self CGImage];
    if (cir) {
        CGRect clipRect = rect;
        clipRect.origin.x       *= self.scale;
        clipRect.origin.y       *= self.scale;
        clipRect.size.width     *= self.scale;
        clipRect.size.height    *= self.scale;
        CGImageRef subCGImage = CGImageCreateWithImageInRect(cir, clipRect);
        if (subCGImage) {
            subImage = [UIImage imageWithCGImage:subCGImage scale:self.scale orientation:self.imageOrientation];
            CGImageRelease(subCGImage);
        } else {
            ALLog(@"Couldn't create subImage in rect: '%@'.", NSStringFromCGRect(rect));
        }
    } else {
        ALLog(@"self.CGImage is somehow nil.");
    }
    return subImage;
}
#pragma mark - decoded file cache
+ (NSString *)cacheDirectory
{
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ALNinePatchImagesCache"];
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error]) {
        ALLog(@"[ERROR] Can't create directory:'%@', error:%@", path, error);
        return nil;
    }
    return path;
}

+ (NSDictionary *)cacheInfoForImageWithPath:(NSString *)path
{
    @synchronized(self) {
        if (CachedImagesInfo == nil) {
            NSMutableDictionary *plist = [NSMutableDictionary dictionaryWithContentsOfFile:[[self cacheDirectory] stringByAppendingPathComponent:CacheInfoPlist]];
            if (plist == nil) {
                plist = [NSMutableDictionary dictionary];
            }
            CachedImagesInfo = plist;
        }
    }
    return CachedImagesInfo[path];
}

+ (BOOL)isValidCachedItemforKey:(NSString *)key
{
    NSDictionary *cachedItem = NSNullToNil(CachedImagesInfo[key]);
    if (cachedItem) {
        NSString *originPath = [self originalPathForImageWithCachedKey:key];
        NSString *cacheImagePath = NSNullToNil(cachedItem[CachedInfoCachedPathKey]);
        if (originPath == nil || cacheImagePath == nil) {
            return NO;
        }
        cacheImagePath = [[self cacheDirectory] stringByAppendingPathComponent: UNNilString(cacheImagePath)];
        if (![[NSFileManager defaultManager] fileExistsAtPath:originPath] || ![[NSFileManager defaultManager] fileExistsAtPath:cacheImagePath]) {
            return NO;
        }
        NSDate *originalMDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:originPath error:nil] fileModificationDate];
        NSDate *decocedDate = [[[NSFileManager defaultManager] attributesOfItemAtPath:cacheImagePath error:nil] fileCreationDate];
        return [originalMDate compare:decocedDate] != NSOrderedDescending;
    }
    return NO;
}

+ (NSString *)originalPathForImageWithCachedKey:(NSString *)key
{
    if (isEmptyString(key)) {
        return nil;
    }
    NSString *basePath = [key pathComponents].firstObject;
    NSString *subPath = [key substringFromIndex:basePath.length];
    NSString *originalPath = nil;
    if ([basePath isEqualToString:HomePathVar]) {
        basePath = NSHomeDirectory();
    } else if ([basePath isEqualToString:BundlePathVar]) {
        basePath = [NSBundle mainBundle].bundlePath;
    }
    if (basePath) {
        originalPath = basePath;
    }
    if (!isEmptyString(subPath)) {
        originalPath = [originalPath stringByAppendingString:subPath];
    }
    return originalPath;
}

+ (NSString *)cachedKeyForImageWithPath:(NSString *)path
{
    NSArray *pathComponents = [[path stringByStandardizingPath] pathComponents];
    NSArray *homePathComponents   = [NSHomeDirectory().stringByStandardizingPath pathComponents];
    NSArray *bundlePathComponents = [[NSBundle mainBundle].bundlePath.stringByStandardizingPath pathComponents];
    if (pathComponents.count >= homePathComponents.count && [homePathComponents isEqualToArray:[pathComponents subarrayWithRange:NSMakeRange(0, homePathComponents.count)]]) {
        path = [HomePathVar stringByAppendingPathComponent: [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(homePathComponents.count, pathComponents.count - homePathComponents.count)]]];
    }
    else if (pathComponents.count >= bundlePathComponents.count && [bundlePathComponents isEqualToArray:[pathComponents subarrayWithRange:NSMakeRange(0, bundlePathComponents.count)]]) {
        path = [BundlePathVar stringByAppendingPathComponent: [NSString pathWithComponents:[pathComponents subarrayWithRange:NSMakeRange(bundlePathComponents.count, pathComponents.count - bundlePathComponents.count)]]];
    }
    return [path stringByStandardizingPath];
}

+ (NSString *)UUIDString
{
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    CFRelease(uuid);
    return uuidString;
}

@end


@implementation NSString (NinePatchPath)

+ (NSString *)ninePatchPathWithImageName:(NSString *)imageName
{
    NSString *resourcePath = [[NSBundle mainBundle] pathForResource:[imageName stringByAppendingString:@".9"] ofType:@"png"];
    if (isEmptyString(resourcePath)) {
        resourcePath = [[NSBundle mainBundle] pathForResource:[imageName stringByAppendingFormat:@".9@%dx", (int)[UIScreen mainScreen].scale] ofType:@"png"];
    }
    if (isEmptyString(resourcePath)) {//default is HD image
        resourcePath = [[NSBundle mainBundle] pathForResource:[imageName stringByAppendingString:@".9@2x"] ofType:@"png"];
    }
    return resourcePath;
}

@end
