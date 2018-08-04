//
//  MSImageFile.h
//  MetalShaderShowcase
//
//  Created by Mark Lim Pak Mun on 20/07/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//


#import <Cocoa/Cocoa.h>

@interface MSSImageFile: NSObject

@property NSImage * _Nonnull thumbnail;
@property NSString * _Nonnull fileName;

- (nonnull instancetype) initWithURL:(nonnull NSURL *)url;

@end
