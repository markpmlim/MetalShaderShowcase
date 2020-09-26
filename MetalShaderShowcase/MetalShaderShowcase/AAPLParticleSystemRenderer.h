/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Metal Particle System Renderer for Metal Shader Showpiece. Acts as the update and render delegate for the view controller and performs rendering for the particle system.
 */

#include <TargetConditionals.h>
#if TARGET_OS_IOS
#import "AAPLViewController.h"
#else
#import "MSSViewController.h"
#endif

#import "AAPLView.h"
#import "AAPLMesh.h"
#import "AAPLTexture.h"
#import "AAPLRenderer.h"
#import <Metal/Metal.h>

@interface AAPLParticleSystemRenderer : AAPLRenderer

@end
