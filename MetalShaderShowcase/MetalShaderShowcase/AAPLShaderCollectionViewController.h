/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 The CollectionViewController for the CollectionView of the shaders.
 */

#include <TargetConditionals.h>

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

typedef enum
{
    Phong, Wood, Fog, CelShading, SphereMap, NormalMap, ParticleSystem
} ShaderType;

// macOS - NSViewController ref: Apple's CocoaSlideCollection source code
// That demo handles double-clicks.
@interface AAPLShaderCollectionViewController : UICollectionViewController

// renderer will create a default device at init time.
@property (nonatomic, readonly) id <MTLDevice> device;

@end
