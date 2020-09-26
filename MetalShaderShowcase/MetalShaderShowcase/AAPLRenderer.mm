/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Metal Renderer for Metal Shader Showpiece. Acts as the update and render delegate for the view controller and performs rendering. In MetalShaderShowpiece, the renderer draws a few objects using different shaders.
 */

#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import "AAPLViewController.h"
#else
#import "MSSViewController.h"
#endif

#import "AAPLRenderer.h"
#import "AAPLView.h"
#import "AAPLTransforms.h"
#import "AAPLSharedTypes.h"
#import "AAPLTeapotMesh.h"
#import "AAPLMesh.h"


// An AAPLRenderer object is instantiated whenever a colletionViewItem is selected.
@implementation AAPLRenderer
{
    id <MTLLibrary> _defaultLibrary;
    id <MTLCommandQueue> _commandQueue;
    dispatch_semaphore_t _inflight_semaphore;
    id <MTLDepthStencilState> _depthState;
    
    // Shader names
    NSString* _vertexShaderName;
    NSString* _fragmentShaderName;
    
    // Texture
    AAPLTexture *_texture;
    
    // Mesh
    AAPLMesh* _mesh;
}

// Called by the executeProgram method of MSSViewController.
- (instancetype) initWithName:(NSString*)name
				 vertexShader:(NSString*)vertexShaderName
			   fragmentShader:(NSString*)fragmentShaderName
						 mesh:(AAPLMesh*)mesh
{
    self = [super init];
    
    if (self)
    {
        _name = name;
        _vertexShaderName = vertexShaderName;
        _fragmentShaderName = fragmentShaderName;
        
        // Setting sample count to 4 will render with MSAA (multi-sample anti-aliasing).
        _sampleCount = 4;
        _depthPixelFormat = MTLPixelFormatDepth32Float;
        _stencilPixelFormat = MTLPixelFormatInvalid;
        
        // Find a usable Device
        _device = MTLCreateSystemDefaultDevice();
        
        _mesh = mesh;
        
        // Create a new command queue
        _commandQueue = [_device newCommandQueue];
        
        _defaultLibrary = [_device newDefaultLibrary];
        if (!_defaultLibrary)
        {
            NSLog(@">> ERROR: Couldnt create a default shader library");
            
            // assert here becuase if the shader libary isnt loading, nothing good will happen
            assert(0);
        }

        _inflight_semaphore = dispatch_semaphore_create(kInFlightCommandBuffers);

        _blending = NO;
        _depthWriteEnabled = YES;

    }
    return self;
}

// The Renderer object will be used to test the sphere and normal map shaders
- (instancetype) initWithName:(NSString*)name
				 vertexShader:(NSString*)vertexShaderName
			   fragmentShader:(NSString*)fragmentShaderName
						 mesh:(AAPLMesh*)mesh
					  texture:(AAPLTexture*)texture
{
    self = [self initWithName:name
				 vertexShader:vertexShaderName
			   fragmentShader:fragmentShaderName
						 mesh:mesh];
    
    _texture = texture;
    
    return self;
}

#pragma mark RENDER VIEW DELEGATE METHODS

// Called by the MSSViewController method "executeShaderProgram"
- (void) configure:(AAPLView *)view
{
    view.depthPixelFormat   = _depthPixelFormat;
    view.stencilPixelFormat = _stencilPixelFormat;
    view.sampleCount        = _sampleCount;
    
    _dynamicConstantBuffer = [_device newBufferWithLength:kMaxBufferBytesPerFrame
												  options:0];
    _dynamicConstantBuffer.label = [NSString stringWithFormat:@"ConstantBuffer"];
    
    [self initializePipelineStateWithVertexShader:_vertexShaderName
								   fragmentShader:_fragmentShaderName
										 blending:_blending];
    
    MTLDepthStencilDescriptor *depthStateDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthStateDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthStateDesc.depthWriteEnabled = _depthWriteEnabled;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthStateDesc];
    
    if (_texture)
    {
        CGSize  texture_size;
        texture_size.width  = _texture.width;
        texture_size.height = _texture.height;
        
        MTLTextureDescriptor *texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                           width:texture_size.width
                                                                                          height:texture_size.height
                                                                                       mipmapped:NO];
        if (!texDesc)
        {
            NSLog(@">> ERROR: Failed creating a texture descriptor!");
        }
    }
}

// Internal method.
- (void) initializePipelineStateWithVertexShader:(NSString*)vertexShaderName
								  fragmentShader:(NSString*)fragmentShaderName
										blending:(BOOL)blending
{
    NSUInteger sampleCount = 4;
    MTLPixelFormat depthPixelFormat = MTLPixelFormatDepth32Float;
    
    // load the vertex program into the library
    id <MTLFunction> vertexProgram = [_defaultLibrary newFunctionWithName:vertexShaderName];
    if (!vertexProgram)
    {
        NSLog(@">> ERROR: Couldnt load vertex function \"%@\"from default library", vertexShaderName);
        assert(0);
    }
    
    // load the fragment program into the library
    id <MTLFunction> fragmentProgram = [_defaultLibrary newFunctionWithName:fragmentShaderName];
    if (!fragmentProgram)
    {
        NSLog(@">> ERROR: Couldnt load fragment function from default library");
        assert(0);
    }
    
    //  create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.label = @"MyPipeline";
    [pipelineStateDescriptor setSampleCount: sampleCount];
    [pipelineStateDescriptor setVertexFunction:vertexProgram];
    [pipelineStateDescriptor setFragmentFunction:fragmentProgram];
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineStateDescriptor.depthAttachmentPixelFormat = depthPixelFormat;
    
    if (blending == YES)
    {
        //Enable Blending
        pipelineStateDescriptor.colorAttachments[0].blendingEnabled = YES;
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    }
    
    MTLRenderPipelineReflection *reflectionObj;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor
														   options:MTLPipelineOptionArgumentInfo
														reflection:&reflectionObj
															 error:nil];
    _reflection = reflectionObj;
}

// Internal method
- (void) renderObject:(id <MTLRenderCommandEncoder>)renderEncoder
				 view:(AAPLView *)view
		 bufferOffset:(uint32_t)offset
				 name:(NSString *)name
{
    [renderEncoder pushDebugGroup:name];
    [renderEncoder setRenderPipelineState:_pipelineState];
    
    // Go through the reflection items and set the buffers
    for (MTLArgument *arg in _reflection.vertexArguments)
    {
		// When is the name property set? A call to the method
		// newRenderPipelineStateWithDescriptor:options:reflection:error:
        if ([arg.name isEqualToString:@"vertices"])
        {
            [renderEncoder setVertexBuffer:_mesh.vertex_buffer
									offset:0
								   atIndex:arg.index];
        }
        else if ([arg.name isEqualToString:@"normals"])
        {
            [renderEncoder setVertexBuffer:_mesh.normal_buffer
									offset:0
								   atIndex:arg.index];
        }
        else if ([arg.name isEqualToString:@"uvs"])
        {
            [renderEncoder setVertexBuffer:_mesh.uv_buffer
									offset:0
								   atIndex:arg.index];
        }
        else if ([arg.name isEqualToString:@"uniforms"])
        {
            [renderEncoder setVertexBuffer:_dynamicConstantBuffer
									offset:offset
								   atIndex:arg.index];
        }
        else if ([arg.name isEqualToString:@"tangents"])
        {
            [renderEncoder setVertexBuffer:_mesh.tangents_buffer
									offset:0
								   atIndex:arg.index];
        }
        else if ([arg.name isEqualToString:@"bitangents"])
        {
            [renderEncoder setVertexBuffer:_mesh.bitangents_buffer
									offset:0
								   atIndex:arg.index];
        }
    }
    
    // Pass parameters to the fragment function.
    for (MTLArgument *arg in _reflection.fragmentArguments)
    {
        if (arg.type == MTLArgumentTypeTexture)
        {
            [renderEncoder setFragmentTexture:_texture.texture
									  atIndex:arg.index];
        }
    }
    
    // Tell the render context we want to draw our primitives
    [renderEncoder drawIndexedPrimitives:_mesh.primitive_type
							  indexCount:_mesh.index_count
							   indexType:MTLIndexTypeUInt16
							 indexBuffer:_mesh.index_buffer
					   indexBufferOffset:0];
    [renderEncoder popDebugGroup];
}

#pragma mark VIEW DELEGATE (AAPLViewDelegate) METHODS
- (void) render:(AAPLView *)view
{
    // Per frame updates here
    dispatch_semaphore_wait(_inflight_semaphore,
							DISPATCH_TIME_FOREVER);
    
    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    // Create a render command encoder so we can render into something
    // Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
    //   holding onto the drawable and blocking the display pipeline any longer than necessary
    MTLRenderPassDescriptor *renderPassDescriptor = view.renderPassDescriptor;
    if (renderPassDescriptor)
    {
        // Final pass rendering code here
        id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder setDepthStencilState:_depthState];
        
        [self renderObject:renderEncoder
					  view:view
			  bufferOffset:0
					  name:@"Teapot"];
        
        [renderEncoder endEncoding];
        
        // Call the view's completion handler which is required by the view
		// since it will signal its semaphore and set up the next buffer
        __block dispatch_semaphore_t block_sema = _inflight_semaphore;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
            dispatch_semaphore_signal(block_sema);
        }];
        
        // Schedule a present once the framebuffer is complete
        [commandBuffer presentDrawable:view.currentDrawable];
        
        // Finalize rendering here. this will push the command buffer to the GPU
        [commandBuffer commit];
    }
    else
    {
        // Release the semaphore to keep things synchronized even if we couldn't render
        dispatch_semaphore_signal(_inflight_semaphore);
    }    
}

// Called by an instance of AAPLView via its "display" method.
- (void) reshape:(AAPLView *)view
{
    // When reshape is called, update the view and projection matricies since this
    // means the view orientation or size changed
    float aspect = fabs(view.bounds.size.width / view.bounds.size.height);
    
    AAPL::Uniforms_t* bufferPointer = (AAPL::Uniforms_t *)[_dynamicConstantBuffer contents];
    bufferPointer->view_matrix = AAPL::lookAt(kEye, kCenter, kUp);
    bufferPointer->projection_matrix = AAPL::perspective_fov(kFOVY,
															 aspect,
															 0.1f, 100.0f);
}

#pragma mark VIEW CONTROLLER DELEGATE (AAPLViewControllerDelegate) METHODS
// cf MSSViewController.h file (renderPass method)
- (void) update:(PlatformViewController *)controller
{
    simd::float4x4 model_matrix = AAPL::translate(_mesh.translate_x,
                                                  _mesh.translate_y,
                                                  _mesh.translate_z) * AAPL::rotate(_rotation,
                                                                                    0.0f, 1.0f, 0.0f);
    
    // Get pointer to the inflight buffer.
    AAPL::Uniforms_t* bufferPointer = (AAPL::Uniforms_t *)[_dynamicConstantBuffer contents];
    bufferPointer->model_matrix = model_matrix;
    
    _rotation += controller.timeSinceLastDraw * 50.0f;
}

// Not called.
- (void) viewController:(PlatformViewController *)controller
			  willPause:(BOOL)pause
{
    // timer is suspended/resumed
    // Can do any non-rendering related background work here when suspended
}


@end
