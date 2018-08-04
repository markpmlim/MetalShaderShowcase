//
//  MSCollectionViewItem.h
//  MetalShaderShowcase
//
//  Created by Mark Lim Pak Mun on 20/07/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class MSSImageFile;

// this is a sub-class of NSViewController
@interface MSSCollectionViewItem : NSCollectionViewItem

@property (readwrite, nonatomic) MSSImageFile *imageFile;

@end
