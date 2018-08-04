/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 A class to represent a mesh and its buffers used for drawing.
 */

#import "AAPLMesh.h"
#include "AAPLSharedTypes.h"

@implementation AAPLMesh

+ (instancetype) sharedInstance
{
    NSLog(@"Error: Should never enter AAPLMesh sharedInstance!");
    assert(0);
    return [[self alloc] init];
}

@end
