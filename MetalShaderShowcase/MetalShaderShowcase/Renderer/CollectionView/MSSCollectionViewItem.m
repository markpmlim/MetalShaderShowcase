//
//  MSCollectionViewItem.m
//  MetalShaderShowcase
//
//  Created by Mark Lim Pak Mun on 20/07/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//

#import "MSSCollectionViewItem.h"
#import "MSSImageFile.h"
#import "MSSViewController.h"

@interface MSSCollectionViewItem () {
}

// isViewLoaded and isSelected?
@end

@implementation MSSCollectionViewItem

// multiple selection of items are not allowed - ref NSCollectionView property.
- (void) setImageFile:(MSSImageFile *)imgFile {
    if (self.isViewLoaded) {
        if (imgFile != nil) {
            _imageFile = imgFile;
            self.imageView.image = _imageFile.thumbnail;
            self.textField.stringValue = [_imageFile.fileName stringByDeletingPathExtension];
        }
        else {
            self.imageView.image = nil;
        }
    }
}


// This method will set the background color of the currently selected collection view item.
- (void) setHighlightState:(NSCollectionViewItemHighlightState)highlightState {
    if (highlightState == NSCollectionViewItemHighlightForSelection) {
        self.view.layer.backgroundColor = [[NSColor redColor] CGColor];
    }
    else {
        self.view.layer.backgroundColor = [[NSColor lightGrayColor] CGColor];
    }
}

- (void) viewDidLoad {
    [super viewDidLoad];

    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = [[NSColor lightGrayColor] CGColor];
}

- (void) mouseDown:(NSEvent *)event {
    NSCollectionView *collectionView = (NSCollectionView *)self.collectionView;
    //[collectionView deselectAll:nil]; // not called
    id delegate = collectionView.delegate;
    NSIndexPath *indexPath = [collectionView indexPathForItem:self];
    [delegate executeShaderProgram:self];
    NSSet *indexPaths = [NSSet setWithObject:indexPath];
    // Call the NSCollectionViewDelegate method directly
    // The method is implemented by the MSSViewController class
    [delegate collectionView:collectionView
didSelectItemsAtIndexPaths:indexPaths];
}

@end

