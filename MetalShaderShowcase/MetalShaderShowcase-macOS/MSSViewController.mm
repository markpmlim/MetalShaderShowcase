//
//  MSSViewController.m
//  MetalShaderShowcase
//
//  Created by Mark Lim Pak Mun on 20/07/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//
//https://stackoverflow.com/questions/37794646/the-right-way-to-make-a-continuously-redrawn-metal-nsview

#import "MSSViewController.h"
#import "AAPLRenderer.h"
#import "MSSImageFile.h"
#import "MSSCollectionViewItem.h"
#import "AAPLCubeMesh.h"
#import "AAPLTeapotMesh.h"
#import "AAPLTexture.h"
#import "AAPLParticleSystemRenderer.h"

@implementation MSSViewController
{
    NSView *_view;          // parent view
@private
    CVDisplayLinkRef _timer;
    dispatch_source_t _displaySource;

    MSSCollectionViewItem *_lastCVItem;
    // boolean to determine if the first draw has occured
    BOOL _firstDrawOccurred;
    
    CFTimeInterval _timeSinceLastDrawPreviousTime;

    AAPLRenderer *_renderer;
    AAPLCubeMesh *_cubeMesh;
    AAPLTeapotMesh *_teapotMesh;
    AAPLTexture *_sphereMapTexture;
    AAPLTexture *_normalMapTexture;
}

// This is the renderer output callback function. The displayLinkContext object
// can be a custom (C struct) object or Objective-C instance.
static CVReturn dispatchGameLoop(CVDisplayLinkRef displayLink,
                                 const CVTimeStamp* now,
                                 const CVTimeStamp* outputTime,
                                 CVOptionFlags flagsIn,
                                 CVOptionFlags* flagsOut,
                                 void* displayLinkContext)
{

    __weak dispatch_source_t source = (__bridge dispatch_source_t)displayLinkContext;
    dispatch_source_merge_data(source, 1);
    return kCVReturnSuccess;
}

- (void) _windowWillClose:(NSNotification*)notification
{
    // Stop the display link when the window is closing because we will
    // not be able to get a drawable, but the display link may continue
    // to fire
    if (notification.object == self.view.window)
    {
        CVDisplayLinkStop(_timer);
        dispatch_source_cancel(_displaySource);
    }
}

- (void) dealloc
{
	if (_timer)
	{
		// Stop the display link BEFORE releasing anything in the view
		// otherwise the display link thread may call into the view and crash
		// when it encounters something that has been release
		CVDisplayLinkStop(_timer);
		dispatch_source_cancel(_displaySource);

		CVDisplayLinkRelease(_timer);
		_displaySource = nil;
	}
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    _cubeMesh = [AAPLCubeMesh sharedInstance];
    _teapotMesh = [AAPLTeapotMesh sharedInstance];
    id <MTLDevice> device = MTLCreateSystemDefaultDevice();

    [self loadAssets: device];
    [self configureCollectionView];

    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    // Register to be notified when the window closes so we can stop the displaylink.
    [notificationCenter addObserver:self
                           selector:@selector(_windowWillClose:)
                               name:NSWindowWillCloseNotification
                             object:self.view.window];

    _displaySource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD,
                                            0,
                                            0,
                                            dispatch_get_main_queue());
    __block MSSViewController* weakSelf = self;
    dispatch_source_set_event_handler(_displaySource, ^() {
        // Both statements will be executed per frame update.
        [weakSelf renderPass];
        // The following statement is necessary to set the "_layerSizeDidUpdate"
        // ivar of APPLView.
        [self->renderView setNeedsDisplay:YES];
    });
    dispatch_resume(_displaySource);
    CVReturn cvReturn;

    // Create a display link capable of being used with all active displays
    cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&_timer);

    // Set the renderer output callback function to dispatchGameLoop
    // The "_displaySource" object is passed to the dispatchGameLoop function
    cvReturn = CVDisplayLinkSetOutputCallback(_timer,
                                              &dispatchGameLoop,
                                              (__bridge void *)_displaySource);
    cvReturn = CVDisplayLinkSetCurrentCGDisplay(_timer,
                                                CGMainDisplayID());
    CVDisplayLinkStart(_timer);
}

// The graphics are in the Assets.xcassets folder.
// They will be compressed in the Assets.car.
- (void) loadAssets:(id <MTLDevice>)device
{
    shaderNames = [NSArray arrayWithObjects:
                      @"PhongShader", @"WoodShader",
                      @"FogShader", @"CelShader",
                      @"SphereMapShader", @"NormalMapShader",
                      @"ParticleShader", nil];
    imageCollection = [NSMutableArray arrayWithCapacity:shaderNames.count];
    for (int i=0; i < shaderNames.count; i++)
    {
        MSSImageFile *imageFile = [[MSSImageFile alloc] initWithName:shaderNames[i]];
        imageCollection[i] = imageFile;
    }

    _sphereMapTexture = [[AAPLTexture alloc] initWithResourceName:@"SphereMap"
                                                        extension:@"jpg"];
    BOOL isAcquired = [_sphereMapTexture finalize:device];
    if (!isAcquired)
    {
        NSLog(@">> ERROR: Failed creating an input 2d texture!");
        assert(0);
    }
    _normalMapTexture = [[AAPLTexture alloc] initWithResourceName:@"NormalMap"
                                                        extension:@"png"];
    isAcquired = [_normalMapTexture finalize:device];
    if (!isAcquired)
    {
        NSLog(@">> ERROR: Failed creating an input 2d texture!");
        assert(0);
    }
}

- (void) viewWillAppear
{
    // The collection view's delegate is set in IB
    MSSViewController *mvc = (MSSViewController *)collectionView.delegate;
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:0
                                                 inSection:0];
    NSCollectionViewItem *item = [collectionView itemAtIndexPath:indexPath];
    [self executeShaderProgram:item];
    NSSet *indexPaths = [NSSet setWithObject:indexPath];
    [mvc collectionView:collectionView
didSelectItemsAtIndexPaths:indexPaths];
}

- (void) setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (void) configureCollectionView
{
    NSCollectionViewFlowLayout *flowLayout = [NSCollectionViewFlowLayout alloc];
    flowLayout.itemSize = NSMakeSize(160.0, 120.0);
    flowLayout.sectionInset = (NSEdgeInsets){10.0, 10.0, 10.0, 0.0};
    flowLayout.minimumInteritemSpacing = 10.0;
    flowLayout.minimumLineSpacing = 10.0;
    flowLayout.scrollDirection = NSCollectionViewScrollDirectionVertical;
    _view.wantsLayer = YES;         // this can be set in IB.
    collectionView.collectionViewLayout = flowLayout;
    // Note: collection view's layer must be set in IB.
    collectionView.layer.backgroundColor = [[NSColor blackColor] CGColor];
    // The following flags have been set in IB.
    //collectionView.selectable = YES;
    //collectionView.allowsEmptySelection = YES;
    //collectionView.allowsMultipleSelection = NO;
}

- (MSSImageFile *) imageFileAtIndexPath:(NSIndexPath *)indexPath
{
    return imageCollection[indexPath.item];
}

// The CollectionView's data source is set in IB.
#pragma mark NSCollectionViewDataSource Methods

// This is an optional method
- (NSInteger) numberOfSectionsInCollectionView:(NSCollectionView *)cv
{
    // The collection view used has only 1 section.
    return 1;
}

// This is a required method
- (NSInteger) collectionView:(NSCollectionView *)cv
      numberOfItemsInSection:(NSInteger)section
{
    return imageCollection.count;
}

// This is a required method - called by the instance of NSCollectionView
- (NSCollectionViewItem *) collectionView:(NSCollectionView *)cv
      itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath
{
    // Message back to the collectionView, asking it to make a "MSCollectionView" item
    // associated with the given item indexPath.
    // The collectionView will first check whether an NSNib or item Class
    // has been registered with that name (via -registerNib:forItemWithIdentifier: or
    // -registerClass:forItemWithIdentifier:).  Failing that, the collectionView will search
    // for a .nib file named "MSSCollectionView".
    // Since our .nib file is named "MSSCollectionView.nib", no registration is necessary.
    MSSCollectionViewItem *item = (MSSCollectionViewItem *)[cv makeItemWithIdentifier:@"MSSCollectionViewItem"
                                                                       forIndexPath:indexPath];
    if (item != nil)
    {
        MSSImageFile *imageFile = [self imageFileAtIndexPath:indexPath];
        item.imageFile = imageFile;
    }
    return item;
}

#pragma mark NSCollectionViewDelegate methods
// Should be called by NSCollectionView's deselectAll method.
- (NSSet<NSIndexPath *> *) collectionView:(NSCollectionView *)cv
          shouldDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
    //printf("shouldDeselectItemsAtIndexPaths\n");
    return indexPaths;
}

// Should be called by NSCollectionView's deselectAll method.
- (void) collectionView:(NSCollectionView *)cv
didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
    //printf("didDeselectItemsAtIndexPaths\n");
    for (NSIndexPath *indexPath in indexPaths)
    {
        NSCollectionViewItem *cvItem = [cv itemAtIndexPath:indexPath];
        [cvItem setHighlightState:NSCollectionViewItemHighlightForSelection];
        [cvItem setSelected:YES];
    }
    return;
}

// Should be called by NSCollectionView's selectAll method.
- (NSSet<NSIndexPath *> *) collectionView:(NSCollectionView *)cv
            shouldSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
    //printf("shouldSelectItemsAtIndexPaths\n");
    return indexPaths;
}

// This method is called directly by 2 methods of this demo.
// cf   MSSCollectionViewItem - mouseDown:
//      MSSViewController - viewWillAppear
- (void) collectionView:(NSCollectionView *)cv
    didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths
{
    if (_lastCVItem != nil)
    {
        // This ivar is nil on first run.
        [_lastCVItem setHighlightState:NSCollectionViewItemHighlightForDeselection];
    }
    for (NSIndexPath *indexPath in indexPaths)
    {
        NSCollectionViewItem *cvItem = [cv itemAtIndexPath:indexPath];
        [cvItem setHighlightState:NSCollectionViewItemHighlightForSelection];
        [cvItem setSelected:YES];
    }
    // We expect only one collection view item since multiple selection has been disabled.
     NSIndexPath *indexPath = (NSIndexPath *)[[indexPaths allObjects] objectAtIndex:0];
    _lastCVItem = (MSSCollectionViewItem *)[cv itemAtIndexPath:indexPath];
    return;
}

// An instance of AAPLRender is created whenever a MSSCollectionViewItem is selected.
- (void) executeShaderProgram:(id)sender
{
    //[collectionView deselectAll:nil]; // not called

    MSSCollectionViewItem *collectionViewItem = (MSSCollectionViewItem *)sender;
    NSString *shaderName = [collectionViewItem.imageFile.fileName stringByDeletingPathExtension];
    NSUInteger index = [shaderNames indexOfObject:shaderName];

    if (index != NSNotFound)
    {
        // create the renderer object.
        switch (index)
        {
            case Phong:
            _renderer = [[AAPLRenderer alloc] initWithName:@"Phong Shader"
                                              vertexShader:@"phong_vertex"
                                            fragmentShader:@"phong_fragment"
                                                      mesh:_teapotMesh];
                break;
            case Wood:
                _renderer = [[AAPLRenderer alloc] initWithName:@"Wood Shader"
                                              vertexShader:@"wood_vertex"
                                            fragmentShader:@"wood_fragment"
                                                      mesh:_teapotMesh];
                break;
            case Fog:
            _renderer = [[AAPLRenderer alloc] initWithName:@"Fog Shader"
                                          vertexShader:@"fog_vertex"
                                        fragmentShader:@"fog_fragment"
                                                  mesh:_teapotMesh];
                break;
            case CelShading:
                _renderer = [[AAPLRenderer alloc] initWithName:@"Cel Shader"
                                                  vertexShader:@"cel_shading_vertex"
                                                fragmentShader:@"cel_shading_fragment"
                                                          mesh:_teapotMesh];
                break;
            case SphereMap:
                _renderer = [[AAPLRenderer alloc] initWithName:@"Sphere Map"
                                              vertexShader:@"sphere_map_vertex"
                                            fragmentShader:@"sphere_map_fragment"
                                                      mesh:_teapotMesh
                                                   texture:_sphereMapTexture];
                break;
            case NormalMap:
                _renderer = [[AAPLRenderer alloc] initWithName:@"Normal Map"
                                                  vertexShader:@"normal_map_vertex"
                                                fragmentShader:@"normal_map_fragment"
                                                          mesh:_cubeMesh
                                                       texture:_normalMapTexture];
                break;
            case ParticleSystem:
                _renderer = [[AAPLParticleSystemRenderer alloc] initWithName:@"Particle System"
                                                                vertexShader:@"particle_vertex"
                                                              fragmentShader:@"particle_fragment"
                                                                        mesh:nil];
                break;
            default:
                break;
        } // switch
        _delegate = _renderer;
        renderView.delegate = _renderer;
        // load all renderer assets before starting game loop
        [_renderer configure:renderView];
    } // if
}

// The main game loop called by the timer above.
- (void) renderPass
{
    // tell our delegate (an instance of AAPLRenderer) to update itself here.
    [_delegate update:self];

    if (!_firstDrawOccurred)
    {
        // set up timing data for display since this is the first time through this loop
        _timeSinceLastDraw             = 0.0;
        _timeSinceLastDrawPreviousTime = CACurrentMediaTime();
        _firstDrawOccurred              = YES;
    }
    else
    {
        // figure out the time since we last we drew
        CFTimeInterval currentTime = CACurrentMediaTime();

        _timeSinceLastDraw = currentTime - _timeSinceLastDrawPreviousTime;
        
        // keep track of the time interval between draws
        _timeSinceLastDrawPreviousTime = currentTime;
    }

    assert([renderView isKindOfClass:[AAPLView class]]);

    [renderView display];
}
@end
