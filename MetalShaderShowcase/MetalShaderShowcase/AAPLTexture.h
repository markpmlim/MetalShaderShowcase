/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Simple Utility class for creating a 2d texture
 */

#include <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import <Metal/Metal.h>

@interface AAPLTexture : NSObject

@property (nonatomic, readonly)  id <MTLTexture>  texture;
@property (nonatomic, readonly)  MTLTextureType   target;
@property (nonatomic, readonly)  uint32_t         width;
@property (nonatomic, readonly)  uint32_t         height;
@property (nonatomic, readonly)  uint32_t         depth;
@property (nonatomic, readonly)  uint32_t         format;
@property (nonatomic, readonly)  NSString        *path;
@property (nonatomic, readonly)  BOOL             hasAlpha;
@property (nonatomic, readwrite) BOOL             flip;

- (id) initWithResourceName:(NSString *)name
                  extension:(NSString *)ext;

- (BOOL) finalize:(id<MTLDevice>)device;

@end
