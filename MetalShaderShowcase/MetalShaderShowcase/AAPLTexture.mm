/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Simple Utility class for creating a 2d texture
 */

#import "AAPLTexture.h"

@implementation AAPLTexture
{
@private
	id <MTLTexture>	 _texture;
	MTLTextureType	 _target;
	uint32_t		 _width;
	uint32_t		 _height;
	uint32_t		 _depth;
	uint32_t		 _format;
	BOOL			 _hasAlpha;
	BOOL			 _flip;
	NSString		*_path;
}

- (instancetype) initWithResourceName:(NSString *)name
							extension:(NSString *)ext
{
	NSString *path = [[NSBundle mainBundle] pathForResource:name
													 ofType:ext];
	
	if (!path)
	{
		return nil;
	} // if
	
	self = [super init];
	
	if (self)
	{
		_path	  = path;
		_width	  = 0;
		_height	  = 0;
		_depth	  = 1;
		_format	  = MTLPixelFormatRGBA8Unorm;
		_target	  = MTLTextureType2D;
		_texture  = nil;
		_hasAlpha = NO;
		_flip	  = YES;
	} // if
	
	return self;
} // initWithResourceName

- (void) dealloc
{
	_path	 = nil;
	_texture = nil;
} // dealloc

- (void) setFlip:(BOOL)flip
{
	_flip = flip;
} // setFlip

// assumes png file
- (BOOL) finalize:(id <MTLDevice>)device
{
	// macOS - initWithContentsOfFile: or imageNamed:
#if TARGET_OS_IOS
	UIImage *pImage = [UIImage imageWithContentsOfFile:_path];
#else
    NSImage *pImage = [[NSImage alloc] initWithContentsOfFile:_path];
#endif
	if (!pImage)
	{
		pImage = nil;

		return NO;
	} // if

	CGColorSpaceRef pColorSpace = CGColorSpaceCreateDeviceRGB();
	
	if (!pColorSpace)
	{
		pImage = nil;

		return NO;
	} // if
#if TARGET_OS_IOS
    CGImageRef cgImage = pImage.CGImage;
#else
    NSRect proposedRect = NSMakeRect(0, 0,
                                     pImage.size.width, pImage.size.height);
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    CGImageRef cgImage = [pImage CGImageForProposedRect:&proposedRect
                                                context:context
                                                  hints:nil];
#endif
	_width	= uint32_t(CGImageGetWidth(cgImage));
	_height = uint32_t(CGImageGetHeight(cgImage));

	uint32_t width	  = _width;
	uint32_t height	  = _height;
	uint32_t rowBytes = width * 4;

	CGContextRef pContext = CGBitmapContextCreate(NULL,
												  width,
												  height,
												  8,
												  rowBytes,
												  pColorSpace,
												  CGBitmapInfo(kCGImageAlphaPremultipliedLast));

	CGColorSpaceRelease(pColorSpace);

	if (!pContext)
	{
		return NO;
	} // if

	CGRect bounds = CGRectMake(0.0f, 0.0f,
							   width, height);
	
	CGContextClearRect(pContext, bounds);
	
	// Vertical Reflect
	if (_flip)
	{
		// Do we have to flip on macOS?
		CGContextTranslateCTM(pContext, width, height);
		CGContextScaleCTM(pContext, -1.0, -1.0);
	} // if
	
	CGContextDrawImage(pContext, bounds, cgImage);

	pImage = nil;

	MTLTextureDescriptor *pTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
																						width:width
																					   height:height
																					mipmapped:NO];
	_target	 = pTexDesc.textureType;
	_texture = [device newTextureWithDescriptor:pTexDesc];

	pTexDesc = nil;

	if (!_texture)
	{
		CGContextRelease(pContext);
		
		return NO;
	} // if

	const void *pPixels = CGBitmapContextGetData(pContext);

	if (pPixels != NULL)
	{
		MTLRegion region = MTLRegionMake2D(0, 0, width, height);
		
		[_texture replaceRegion:region
					mipmapLevel:0
					  withBytes:pPixels
					bytesPerRow:rowBytes];
	} // if

	CGContextRelease(pContext);

	return YES;
} // finalize

@end
