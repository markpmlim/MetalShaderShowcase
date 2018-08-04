//
//  NSObject+MSImageFile.h
//  MetalShaderShowcase
//
//  Created by Mark Lim Pak Mun on 20/07/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//

#import "MSSImageFile.h"

@implementation MSSImageFile

- (nonnull instancetype) initWithURL:(nonnull NSURL *)url {
    self = [super init];
    if (self != nil) {
        _fileName = [url lastPathComponent];
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((const struct __CFURL *)url.absoluteURL,
                                                                  nil);
        CFStringRef imageSourceType = CGImageSourceGetType(imageSource);
        if (imageSourceType != NULL) {
            NSDictionary *thumbnailOptions = [[NSDictionary alloc] initWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES], (NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent,
                                                [NSNumber numberWithInt:160], (NSString *)kCGImageSourceThumbnailMaxPixelSize,
                                                nil];
            CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource,
                                                                      0,
                                                                      (CFDictionaryRef)thumbnailOptions);
            if (imageRef != NULL) {
                _thumbnail = [[NSImage alloc] initWithCGImage:imageRef
                                                         size:NSZeroSize];
            }
            else {
                self = nil;
            }
        }
        else {
            self = nil;
        }
    }
    return self;

}

@end
