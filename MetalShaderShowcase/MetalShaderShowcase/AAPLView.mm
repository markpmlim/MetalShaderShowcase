/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 View for Metal Sample Code. Manages screen drawable framebuffers and expects a delegate to repond to render commands to perform drawing.
 */

#import "AAPLView.h"

@implementation AAPLView
{
@private
	__weak CAMetalLayer *_metalLayer;
	
	BOOL _layerSizeDidUpdate;
	
	id <MTLTexture>	 _depthTex;
	id <MTLTexture>	 _stencilTex;
	id <MTLTexture>	 _msaaTex;
}
@synthesize currentDrawable		 = _currentDrawable;
@synthesize renderPassDescriptor = _renderPassDescriptor;

+ (Class) layerClass
{
	return [CAMetalLayer class];
}

- (void) initCommon
{
#if TARGET_OS_IOS
    self.opaque          = YES;
    self.backgroundColor = nil;
    _metalLayer = (CAMetalLayer *)self.layer;
#else
    self.wantsLayer = YES;      // can be set in IB
    // Note: under macOS, the "layer" property is not an instance of CAMetalLayer.
    self.layer = _metalLayer = [CAMetalLayer layer];
#endif

	_device = MTLCreateSystemDefaultDevice();

	_metalLayer.device			= _device;
	_metalLayer.pixelFormat		= MTLPixelFormatBGRA8Unorm;

    // This is the default but if we wanted to perform compute on the final rendering layer
    // we could set this to NO
	_metalLayer.framebufferOnly = YES;
}

#if TARGET_OS_IOS
- (void) didMoveToWindow
{
	self.contentScaleFactor = self.window.screen.nativeScale;
}
#endif

- (id) initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];

	if (self)
	{
		[self initCommon];
	}

	return self;
}

// For NSView/UIView objects instantiated via xib or storyboard file.
- (instancetype) initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	if (self)
	{
		[self initCommon];
	}
	return self;
}

- (void) releaseTextures
{
	_depthTex	= nil;
	_stencilTex = nil;
	_msaaTex	= nil;
}

// Internal method; call by APPLView renderPassDescriptor.
// The parameter "texture" is the "texture" property of the currentDrawable of APPLView.
- (void) setupRenderPassDescriptorForTexture:(id <MTLTexture>) texture
{
	// create lazily
	if (_renderPassDescriptor == nil)
    {
        // Called once to create an instance of MTLRenderPassDescriptor.
		_renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    }

	// Create a color attachment every frame since we have to recreate the texture every frame
	MTLRenderPassColorAttachmentDescriptor *colorAttachment = _renderPassDescriptor.colorAttachments[0];
	colorAttachment.texture = texture;
	
	// Make sure to clear every frame for best performance
	colorAttachment.loadAction = MTLLoadActionClear;
	colorAttachment.clearColor = MTLClearColorMake(0.65f, 0.65f, 0.65f, 1.0f);
	
	// If sample count is greater than 1, render into using MSAA, then resolve into our color texture
	if (_sampleCount > 1)
	{
		BOOL doUpdate =		( _msaaTex.width	   != texture.width	 ) ||
							( _msaaTex.height	   != texture.height ) ||
							( _msaaTex.sampleCount != _sampleCount	 );
		
		if (!_msaaTex || (_msaaTex && doUpdate))
		{
            // Executed whether there is a change in the window size and during 1st run.
			MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
																							width: texture.width
																						   height: texture.height
																						mipmapped: NO];
			desc.textureType = MTLTextureType2DMultisample;
        #if TARGET_OS_OSX || TARGET_OS_SIMULATOR
            desc.resourceOptions = MTLResourceStorageModePrivate;   // added
            desc.usage |= MTLTextureUsageRenderTarget;              // added
        #endif

            // Sample count was assigned to the view by the renderer. (configure method)
            // This must match the sample count given to any pipeline state using this render pass descriptor
			desc.sampleCount = _sampleCount;

			_msaaTex = [_device newTextureWithDescriptor: desc];
            // Note: the property of _metalLayer "framebufferOnly" has been set to true.
		}

		// When multisampling, perform rendering to _msaaTex, then resolve
		// to 'texture' at the end of the scene
		colorAttachment.texture = _msaaTex;
		colorAttachment.resolveTexture = texture;

		// Set store action to resolve in this case
		colorAttachment.storeAction = MTLStoreActionMultisampleResolve;
	}
	else
	{
		// Store only attachments that will be presented to the screen, as in this case
		colorAttachment.storeAction = MTLStoreActionStore;
	} // color0

	// Now create the depth and stencil attachments

	if (_depthPixelFormat != MTLPixelFormatInvalid)
	{
		BOOL doUpdate =		( _depthTex.width		!= texture.width  ) ||
							( _depthTex.height		!= texture.height ) ||
							( _depthTex.sampleCount != _sampleCount	  );

		if (!_depthTex || doUpdate)
		{
			//	If we need a depth texture and don't have one, or if the depth texture we have is the wrong size
			//	Then allocate one of the proper size
			MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: _depthPixelFormat
																							width: texture.width
																						   height: texture.height
																						mipmapped: NO];

			desc.textureType = (_sampleCount > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
			desc.sampleCount = _sampleCount;
        #if TARGET_OS_OSX || TARGET_OS_SIMULATOR
            desc.resourceOptions = MTLResourceStorageModePrivate;   // added
            desc.usage |= MTLTextureUsageRenderTarget;              // added
        #endif
			_depthTex = [_device newTextureWithDescriptor: desc];

			MTLRenderPassDepthAttachmentDescriptor *depthAttachment = _renderPassDescriptor.depthAttachment;
			depthAttachment.texture = _depthTex;
			depthAttachment.loadAction = MTLLoadActionClear;
			depthAttachment.storeAction = MTLStoreActionDontCare;
			depthAttachment.clearDepth = 1.0;
		}
	} // depth

	if (_stencilPixelFormat != MTLPixelFormatInvalid)
	{
		BOOL doUpdate  =	( _stencilTex.width		  != texture.width	) ||
							( _stencilTex.height	  != texture.height ) ||
							( _stencilTex.sampleCount != _sampleCount	);

		if (!_stencilTex || doUpdate)
		{
			//	If we need a stencil texture and don't have one, or if the depth texture we have is the wrong size
			//	Then allocate one of the proper size
			MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: _stencilPixelFormat
																							width: texture.width
																						   height: texture.height
																						mipmapped: NO];
			
			desc.textureType = (_sampleCount > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
			desc.sampleCount = _sampleCount;
			
			_stencilTex = [_device newTextureWithDescriptor: desc];
			
			MTLRenderPassStencilAttachmentDescriptor* stencilAttachment = _renderPassDescriptor.stencilAttachment;
			stencilAttachment.texture = _stencilTex;
			stencilAttachment.loadAction = MTLLoadActionClear;
			stencilAttachment.storeAction = MTLStoreActionDontCare;
			stencilAttachment.clearStencil = 0;
		}
	} //stencil
}

// This method is called per frame update by the "render" method of
// the APPLRenderer object (cf AAPLRenderer.m)
- (MTLRenderPassDescriptor *)renderPassDescriptor
{
	id <CAMetalDrawable> drawable = self.currentDrawable;
	if (!drawable)
	{
		NSLog(@">> ERROR: Failed to get a drawable!");
		_renderPassDescriptor = nil;
	}
	else
	{
		[self setupRenderPassDescriptorForTexture: drawable.texture];
	}
	
	return _renderPassDescriptor;
}


// Note: the method nextDrawable can return nil.
// A new instance of CAMetalDrawable will be obtained per frame update
// since the AAPLView display method sets "_currentDrawable" to nil.
- (id <CAMetalDrawable>)currentDrawable
{
	if (_currentDrawable == nil)
		_currentDrawable = [_metalLayer nextDrawable];
	
	return _currentDrawable;
}

// Called by the view controller's "renderPass" method per frame update.
- (void) display
{
	// Create autorelease pool per frame to avoid possible deadlock situations
	// because there are 3 CAMetalDrawables sitting in an autorelease pool.

	@autoreleasepool
	{
		// handle display changes here
		if (_layerSizeDidUpdate)
		{
			// set the metal layer to the drawable size in case orientation or size changes
			CGSize drawableSize = self.bounds.size;
        #if TARGET_OS_IOS
            drawableSize.width  *= self.contentScaleFactor;
            drawableSize.height *= self.contentScaleFactor;
        #else
            NSScreen* screen = self.window.screen ? : [NSScreen mainScreen];
            drawableSize.width *= screen.backingScaleFactor;
            drawableSize.height *= screen.backingScaleFactor;
        #endif

			_metalLayer.drawableSize = drawableSize;

            // Call the renderer's delegate reshape method so renderer can resize anything if needed
			[_delegate reshape:self];

            _layerSizeDidUpdate = NO;
		}
		
		// rendering delegate method to ask renderer to draw this frame's content
        // The class AAPLRenderer adopts the AAPLViewDelegate protocol.
		[self.delegate render:self];
		
		// do not retain current drawable beyond the frame.
		// There should be no strong references to this object outside of this view class
		_currentDrawable	= nil;
	}
}

#if TARGET_OS_IOS
- (void) setContentScaleFactor:(CGFloat)contentScaleFactor
{
	[super setContentScaleFactor:contentScaleFactor];
	
	_layerSizeDidUpdate = YES;
}

- (void) layoutSubviews
{
	[super layoutSubviews];
	
	_layerSizeDidUpdate = YES;
}
#else

// These 4 methods are overridden for macOS.
- (void) setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    _layerSizeDidUpdate = YES;
}

- (void) setBoundsSize:(NSSize)newSize
{
    [super setBoundsSize:newSize];
    _layerSizeDidUpdate = YES;
}

// Called when the backing store scale or color space changes.
- (void) viewDidChangeBackingProperties
{
    [super viewDidChangeBackingProperties];
    _layerSizeDidUpdate = YES;
}

// We need to call this whenever a frame update is necessary
// otherwise the AAPLView method "display" will not draw correctly.
// cf MSSViewController source
- (void) setNeedsDisplay:(BOOL)needsDisplay
{
    _layerSizeDidUpdate = YES;
}
#endif

@end
