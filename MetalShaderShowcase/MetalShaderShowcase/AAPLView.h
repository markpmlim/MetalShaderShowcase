/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View for Metal Sample Code. Manages screen drawable framebuffers and expects a delegate to repond
 to render commands to perform drawing.
 */

#include <TargetConditionals.h>

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#define PlatformView UIView
#else
#import <AppKit/AppKit.h>
#define PlatformView NSView
#endif

#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>

@protocol AAPLViewDelegate;

@interface AAPLView : PlatformView
@property (nonatomic, weak) IBOutlet id <AAPLViewDelegate> delegate;

// View has a handle to the metal device when created
@property (nonatomic, readonly) id <MTLDevice> device;

// The current drawable created within the view's CAMetalLayer
@property (nonatomic, readonly) id <CAMetalDrawable> currentDrawable;

// The current framebuffer can be read by delegate during -[MetalViewDelegate render:]
// This call may block until the framebuffer is available.
@property (nonatomic, readonly) MTLRenderPassDescriptor *renderPassDescriptor;

// Set these pixel formats to have the main drawable framebuffer get created with depth and/or stencil attachments
@property (nonatomic) MTLPixelFormat depthPixelFormat;
@property (nonatomic) MTLPixelFormat stencilPixelFormat;
@property (nonatomic) NSUInteger     sampleCount;

// View controller will be call off the main thread
- (void) display;

// Release any color/depth/stencil resources. view controller will call when paused.
- (void) releaseTextures;

@end

// Both required methods are implemented by AAPLRenderer class.
// rendering delegate (App must implement a rendering delegate that responds to these messages
// cf AAPLRenderer.h
@protocol AAPLViewDelegate <NSObject>

@required
// Called if the view changes orientation or size,
// renderer can precompute its view and projection matricies here for example
// rendering delegate (App must implement a rendering delegate that responds to these messages
// cf AAPLRenderer.h
- (void) reshape:(AAPLView *)view;

// delegate should perform all rendering here
- (void) render:(AAPLView *)view;

@end
