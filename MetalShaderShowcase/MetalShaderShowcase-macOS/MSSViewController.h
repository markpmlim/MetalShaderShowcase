//
//  MSSViewController.h
//  MetalShaderShowcase
//
//  Created by Mark Lim Pak Mun on 20/07/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>

@protocol AAPLViewControllerDelegate;

typedef enum
{
    Phong, Wood, Fog, CelShading, SphereMap, NormalMap, ParticleSystem
} ShaderType;

@class MSSImageFile;
@class AAPLView;

// This class implements the method of NSCollectionViewDataSource
// & NSCollectionViewDelegate protocols
@interface MSSViewController : NSViewController<NSCollectionViewDataSource, NSCollectionViewDelegate>
{
    IBOutlet AAPLView *__weak renderView;
    IBOutlet NSCollectionView *__weak collectionView;
    NSMutableArray<MSSImageFile*> *imageCollection;
    NSArray<NSString *> *shaderNames;
}

// "delegate" is a custom property of this sub-class (not inherited)
// The class AAPLRenderer adopts the AAPLViewControllerDelegate protocol.
@property (nonatomic, weak) id <AAPLViewControllerDelegate> delegate;
@property (nonatomic, readonly) NSTimeInterval timeSinceLastDraw;
@property (nonatomic) NSUInteger interval;

// Used to pause and resume the controller.
@property (nonatomic, getter=isPaused) BOOL paused;

- (void) executeShaderProgram:(id)sender;

@end

// Both methods of the following protocol are implemented by the APPLRenderer class.
// Required view controller delegate functions.
@protocol AAPLViewControllerDelegate <NSObject>
@required

// Note this method is called from the thread the main game loop is run
- (void) update:(MSSViewController *)controller;

// called whenever the main game loop is paused, such as when the app is backgrounded
- (void) viewController:(MSSViewController *)controller
              willPause:(BOOL)pause;

@end

