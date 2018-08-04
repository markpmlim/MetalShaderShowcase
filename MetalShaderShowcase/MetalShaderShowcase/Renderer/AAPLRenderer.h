/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Metal Renderer for Metal Shader Showpiece. Acts as the update and render delegate for the view controller
 and performs rendering. In MetalShaderShowpiece, the renderer draws a few objects using different shaders.
 */

#import <simd/simd.h>
#import <MetalKit/MetalKit.h>
#import "AAPLMesh.h"
#import "AAPLView.h"
#import "AAPLTexture.h"
#import "MSSViewController.h"

static const long kMaxBufferBytesPerFrame = 1024*1024;
static const long kInFlightCommandBuffers = 3;
static const vector_float3 kEye    = {0.0f, 0.0f, 0.0f};
static const vector_float3 kCenter = {0.0f, 0.0f, 1.0f};
static const vector_float3 kUp     = {0.0f, 1.0f, 0.0f};
static const float kFOVY          = 65.0f;

@interface AAPLRenderer : NSObject <AAPLViewControllerDelegate, AAPLViewDelegate>
{
@protected
    // Global transform data
    id <MTLBuffer> _dynamicConstantBuffer;
    float _rotation;
    
    BOOL _blending;
    BOOL _depthWriteEnabled;
    
    id <MTLRenderPipelineState> _pipelineState;
    MTLRenderPipelineReflection *_reflection;
}

// renderer will create a default device at init time.
@property (nonatomic) _Nonnull id<MTLDevice> device;

//  These queries exist so the View can initialize a framebuffer that matches
// the expectations of the renderer
@property (nonatomic) MTLPixelFormat depthPixelFormat;
@property (nonatomic) MTLPixelFormat stencilPixelFormat;
@property (nonatomic) NSUInteger sampleCount;

@property (nonatomic) NSString *_Nonnull name;

- (instancetype _Nonnull ) initWithName:(NSString* _Nonnull)name
                 vertexShader:(NSString* _Nonnull)vertexShaderName
               fragmentShader:(NSString* _Nonnull)fragmentShaderName
                         mesh:(AAPLMesh* _Nullable)mesh;

- (instancetype _Nullable ) initWithName:(NSString* _Nonnull)name
                 vertexShader:(NSString* _Nonnull)vertexShaderName
               fragmentShader:(NSString* _Nonnull)fragmentShaderName
                         mesh:(AAPLMesh* _Nullable)mesh
                      texture:(AAPLTexture* _Nonnull)texture;

// this method will be overridden by a sub-class viz. AAPLParticleSystemRenderer
// load all assets before triggering rendering
- (void) configure:(AAPLView *_Nonnull)view;

- (void) initializePipelineStateWithVertexShader:(NSString* _Nonnull)vertexShaderName
                                  fragmentShader:(NSString* _Nonnull)fragmentShaderName
                                        blending:(BOOL)blending;

// AAPLRenderer adopts the AAPLViewDelegate protocol
- (void) reshape:(AAPLView *_Nonnull)view;

@end

