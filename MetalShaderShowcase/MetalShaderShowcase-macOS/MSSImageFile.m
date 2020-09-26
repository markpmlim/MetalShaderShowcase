//
//  MSImageFile.h
//  MetalShaderShowcase
//
//  Created by Mark Lim Pak Mun on 20/07/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//

#import "MSSImageFile.h"

@implementation MSSImageFile

// Call this method to instantiate if the graphics are
// stored in a bundle directory (e.g. main bundle) on disk.
- (nonnull instancetype) initWithURL:(nonnull NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
        _fileName = [url lastPathComponent];
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL((const struct __CFURL *)url.absoluteURL,
                                                                  nil);
        CFStringRef imageSourceType = CGImageSourceGetType(imageSource);
        if (imageSourceType != NULL)
        {
            NSDictionary *thumbnailOptions = [[NSDictionary alloc] initWithObjectsAndKeys:
                                                [NSNumber numberWithBool:YES], (NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent,
                                                [NSNumber numberWithInt:160], (NSString *)kCGImageSourceThumbnailMaxPixelSize,
                                                nil];
            CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSource,
                                                                      0,
                                                                      (CFDictionaryRef)thumbnailOptions);
            if (imageRef != NULL)
            {
                _thumbnail = [[NSImage alloc] initWithCGImage:imageRef
                                                         size:NSZeroSize];
            }
            else
            {
                self = nil;
            }
        }
        else
        {
            self = nil;
        }
        CFRelease(imageSource);
    }
    return self;

}

// Modern Objective-C will take care of deallocation of objects.
-(void) dealloc
{

}

// All the graphics passed in have the same dimensions 640x640
- (nonnull instancetype) initWithName:(NSString *)name
{
    self = [super init];
    _fileName = name;
    NSImage *image = [NSImage imageNamed:name];
    NSRect thumbnailRect = NSMakeRect(0, 0, 160, 160);
    CGImageRef cgImageRef = [image CGImageForProposedRect:&thumbnailRect
                                                  context:nil
                                                    hints:nil];
    _thumbnail = [[NSImage alloc] initWithCGImage:cgImageRef
                                             size:NSZeroSize];
    return self;
}

@end
