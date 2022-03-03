/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of the cross-platform view controller and cross-platform view that displays OpenGL content.
*/
#import "AAPLOpenGLViewController.h"
#import "AAPLOpenGLRenderer.h"
@import GLKit.GLKMath;
#import <simd/simd.h>
#include <math.h>

#ifdef TARGET_MACOS
#import <AppKit/AppKit.h>
#define PlatformGLContext NSOpenGLContext
#else // if!(TARGET_IOS || TARGET_TVOS)
#import <UIKit/UIKit.h>
#define PlatformGLContext EAGLContext
#endif // !(TARGET_IOS || TARGET_TVOS)

@implementation AAPLOpenGLView

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
+ (Class) layerClass
{
    return [CAEAGLLayer class];
}
#endif

@end

@implementation AAPLOpenGLViewController
{
    AAPLOpenGLView *_view;
    AAPLOpenGLRenderer *_openGLRenderer;
    PlatformGLContext *_context;
    GLuint _defaultFBOName;

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
    GLuint _colorRenderbuffer;
    GLuint _depthRenderbuffer;
    CADisplayLink *_displayLink;
#else
    CVDisplayLinkRef _displayLink;
#endif
    
    GLKQuaternion _fromQuaternion;
    GLKQuaternion _toQuaternion;
    
    UILabel* _degreeLabel;
    CGFloat _progress;
    UIButton* _switchButton;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _fromQuaternion = GLKQuaternionIdentity;
    _toQuaternion = GLKQuaternionIdentity;

    _view = (AAPLOpenGLView *)self.view;

    [self prepareView];

    [self makeCurrentContext];

    _openGLRenderer = [[AAPLOpenGLRenderer alloc] initWithDefaultFBOName:_defaultFBOName];

    if(!_openGLRenderer)
    {
        NSLog(@"OpenGL renderer failed initialization.");
        return;
    }

    [_openGLRenderer resize:self.drawableSize];
    
    UIPanGestureRecognizer* panGes = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panAction:)];
    [self.view addGestureRecognizer:panGes];
    
    UIRotationGestureRecognizer* rotationGes = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotationAction:)];
    [self.view addGestureRecognizer:rotationGes];
//    [panGes requireGestureRecognizerToFail:rotationGes];
    
    CGSize btnSize = CGSizeMake(120, 40);
    UIButton* resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [resetBtn setTitle:@"reset" forState:UIControlStateNormal];
    [self.view addSubview:resetBtn];
    [resetBtn addTarget:self action:@selector(resetAction:) forControlEvents:UIControlEventTouchUpInside];
    resetBtn.frame = CGRectMake(self.view.frame.size.width - btnSize.width - 20, 10, btnSize.width, btnSize.height);
    
    UIButton* fromBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [fromBtn setTitle:@"keyframe from" forState:UIControlStateNormal];
    [self.view addSubview:fromBtn];
    [fromBtn addTarget:self action:@selector(fromAction:) forControlEvents:UIControlEventTouchUpInside];
    fromBtn.frame = CGRectMake(self.view.frame.size.width - btnSize.width - 20, 60, btnSize.width, btnSize.height);
    
    UIButton* toBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [toBtn setTitle:@"keyframe to" forState:UIControlStateNormal];
    [self.view addSubview:toBtn];
    [toBtn addTarget:self action:@selector(toAction:) forControlEvents:UIControlEventTouchUpInside];
    toBtn.frame = CGRectMake(self.view.frame.size.width - btnSize.width - 20, 110, btnSize.width, btnSize.height);
    
    _switchButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_switchButton setTitle:@"orig control" forState:UIControlStateNormal];
    [_switchButton setTitle:@"delta control" forState:UIControlStateSelected];
    [self.view addSubview:_switchButton];
    [_switchButton addTarget:self action:@selector(toSwitch:) forControlEvents:UIControlEventTouchUpInside];
    _switchButton.frame = CGRectMake(self.view.frame.size.width - btnSize.width - 20, 170, btnSize.width, btnSize.height);
    
    _degreeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 30, self.view.frame.size.width, 30)];
    _degreeLabel.textAlignment = NSTextAlignmentCenter;
    _degreeLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:_degreeLabel];
}

#if TARGET_MACOS

- (CGSize) drawableSize
{
    CGSize viewSizePoints = _view.bounds.size;

    CGSize viewSizePixels = [_view convertSizeToBacking:viewSizePoints];

    return viewSizePixels;
}

- (void)makeCurrentContext
{
    [_context makeCurrentContext];
}

static CVReturn OpenGLDisplayLinkCallback(CVDisplayLinkRef displayLink,
                                         const CVTimeStamp* now,
                                         const CVTimeStamp* outputTime,
                                         CVOptionFlags flagsIn,
                                         CVOptionFlags* flagsOut,
                                         void* displayLinkContext)
{
    AAPLOpenGLViewController *viewController = (__bridge AAPLOpenGLViewController*)displayLinkContext;

    [viewController draw];
    return YES;
}

- (void)draw
{
    CGLLockContext(_context.CGLContextObj);

    [_context makeCurrentContext];

    [_openGLRenderer draw];

    CGLFlushDrawable(_context.CGLContextObj);
    CGLUnlockContext(_context.CGLContextObj);
}

- (void)prepareView
{
    NSOpenGLPixelFormatAttribute attrs[] =
    {
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        0
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];

    NSAssert(pixelFormat, @"No OpenGL pixel format.");

    _context = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];

    CGLLockContext(_context.CGLContextObj);

    [_context makeCurrentContext];

    CGLUnlockContext(_context.CGLContextObj);

    glEnable(GL_FRAMEBUFFER_SRGB);
    _view.pixelFormat = pixelFormat;
    _view.openGLContext = _context;
    _view.wantsBestResolutionOpenGLSurface = YES;

    // The default framebuffer object (FBO) is 0 on macOS, because it uses a traditional OpenGL
    // pixel format model.
    _defaultFBOName = 0;

    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);

    // Set the renderer output callback function.
    CVDisplayLinkSetOutputCallback(_displayLink, &OpenGLDisplayLinkCallback, (__bridge void*)self);

    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, _context.CGLContextObj, pixelFormat.CGLPixelFormatObj);
}

- (void)viewDidLayout
{
    CGLLockContext(_context.CGLContextObj);

    NSSize viewSizePoints = _view.bounds.size;

    NSSize viewSizePixels = [_view convertSizeToBacking:viewSizePoints];

    [self makeCurrentContext];

    [_openGLRenderer resize:viewSizePixels];

    CGLUnlockContext(_context.CGLContextObj);

    if(!CVDisplayLinkIsRunning(_displayLink))
    {
        CVDisplayLinkStart(_displayLink);
    }
}

- (void) viewWillDisappear
{
    CVDisplayLinkStop(_displayLink);
}

- (void)dealloc
{
    CVDisplayLinkStop(_displayLink);

    CVDisplayLinkRelease(_displayLink);
}

#else

- (void)draw:(id)sender
{
    [EAGLContext setCurrentContext:_context];
    [_openGLRenderer draw];

    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)makeCurrentContext
{
    [EAGLContext setCurrentContext:_context];
}

- (void)prepareView
{
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.view.layer;

    eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking : @NO,
                                     kEAGLDrawablePropertyColorFormat     : kEAGLColorFormatSRGBA8 };
    eaglLayer.opaque = YES;

    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!_context || ![EAGLContext setCurrentContext:_context])
    {
        NSLog(@"Could not create an OpenGL ES context.");
        return;
    }

    [self makeCurrentContext];

    self.view.contentScaleFactor = [UIScreen mainScreen].nativeScale;

    // In iOS & tvOS, you must create an FBO and attach a drawable texture allocated by
    // Core Animation to use as the default FBO for a view.
    glGenFramebuffers(1, &_defaultFBOName);
    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBOName);

    glGenRenderbuffers(1, &_colorRenderbuffer);

    glGenRenderbuffers(1, &_depthRenderbuffer);

    [self resizeDrawable];

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _colorRenderbuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderbuffer);

    // Create the display link so you render at 60 frames per second (FPS).
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(draw:)];

    _displayLink.preferredFramesPerSecond = 60;

    // Set the display link to run on the default run loop (and the main thread).
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

- (CGSize)drawableSize
{
    GLint backingWidth, backingHeight;
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    CGSize drawableSize = {backingWidth, backingHeight};
    return drawableSize;
}

- (void)resizeDrawable
{
    [self makeCurrentContext];

    // First, ensure that you have a render buffer.
    assert(_colorRenderbuffer != 0);

    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)_view.layer];

    CGSize drawableSize = self.drawableSize;

    glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderbuffer);

    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, drawableSize.width, drawableSize.height);

    GetGLError();

    [_openGLRenderer resize:self.drawableSize];
}

- (void)viewDidLayoutSubviews
{
    [self resizeDrawable];
}

- (void)viewDidAppear:(BOOL)animated
{
    [self resizeDrawable];
}

#endif



- (void)panAction:(UIPanGestureRecognizer*)ges {
    CGPoint offset = [ges translationInView:self.view];
//    NSLog(@"offset: %@", NSStringFromCGPoint(offset));
    switch (ges.state) {
        case UIGestureRecognizerStateChanged:
        {
            [ges setTranslation:CGPointZero inView:self.view];
            CGFloat offsetX = 0;
            CGFloat offsetY = 0;
            if(abs(offset.y) > abs(offset.x)) {
                offsetY = offset.y / 100;
            } else {
                offsetX = offset.x / 100;
            }
            if(_switchButton.selected) {
                [_openGLRenderer rotateDeltaWithRadianX:offsetX
                                       withRadianY:offsetY
                                            withRadianZ:0];
                return;
            }
            NSString* text = [_openGLRenderer rotateWithRadianX:offsetX
                                   withRadianY:offsetY
                                   withRadianZ:0];
            _degreeLabel.text = text;
        }
            break;
            
        default:
            break;
    }
}


- (void)rotationAction:(UIRotationGestureRecognizer*)ges {
    CGFloat offset = [ges rotation];
//    NSLog(@"offset: %@", NSStringFromCGPoint(offset));
    switch (ges.state) {
        case UIGestureRecognizerStateChanged:
        {
            [ges setRotation:0];
            CGFloat offsetZ = offset;
            if(_switchButton.selected) {
                [_openGLRenderer rotateDeltaWithRadianX:0
                                       withRadianY:0
                                            withRadianZ:offsetZ];
                return;
            }
            NSString* label = [_openGLRenderer rotateWithRadianX:0
                                   withRadianY:0
                                   withRadianZ:offsetZ];
            _degreeLabel.text = label;
        }
            break;
            
        default:
            break;
    }
}

- (void)resetAction:(UIButton*)button
{
//    NSArray* rotations = [_openGLRenderer allRotations];
    NSString* label = [_openGLRenderer resetRotation];
    _degreeLabel.text = label;
//    float roll  = [[rotations objectAtIndex:0] floatValue];
//    float pitch = [[rotations objectAtIndex:1] floatValue];
//    float yaw   = [[rotations objectAtIndex:2] floatValue];
//
//    GLKQuaternion fromRotationE = [AAPLOpenGLRenderer quaternionWithRoll:0 yaw:0.0001 pitch:0];
//
//    GLKQuaternion toRotationE = [AAPLOpenGLRenderer quaternionWithRoll:roll yaw:yaw pitch:pitch];
//
//
////    roll  = atan2(2 * (toRotationE.w * toRotationE.z + toRotationE.x * toRotationE.y) , 1 - 2 * (toRotationE.z * toRotationE.z + toRotationE.x * toRotationE.x));
////    pitch = asin(simd_clamp(2 * (toRotationE.w * toRotationE.x - toRotationE.y * toRotationE.z) , -1.0f , 1.0f));
////    yaw   = atan2(2 * (toRotationE.w * toRotationE.y + toRotationE.z * toRotationE.x) , 1 - 2 * (toRotationE.x * toRotationE.x + toRotationE.y * toRotationE.y));
//
//    self.view.userInteractionEnabled = NO;
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//
////        [self->_openGLRenderer resetRoll:roll yaw:yaw pitch:pitch];
//        [self makeDistanceFrom:fromRotationE to:toRotationE];
//    });
}

- (void)fromAction:(UIButton*)button
{
    NSArray* rotations = [_openGLRenderer allRotations];
    float roll  = [[rotations objectAtIndex:0] floatValue];
    float pitch = [[rotations objectAtIndex:1] floatValue];
    float yaw   = [[rotations objectAtIndex:2] floatValue];
    
    _fromQuaternion = [AAPLOpenGLRenderer quaternionWithRoll:roll yaw:yaw pitch:pitch];
}

- (void)toAction:(UIButton*)button
{
    NSArray* rotations = [_openGLRenderer allRotations];
    float roll  = [[rotations objectAtIndex:0] floatValue];
    float pitch = [[rotations objectAtIndex:1] floatValue];
    float yaw   = [[rotations objectAtIndex:2] floatValue];
    
    _toQuaternion = [AAPLOpenGLRenderer quaternionWithRoll:roll yaw:yaw pitch:pitch];
    _progress = 0;
    [self makeDistanceFrom:_fromQuaternion to:_toQuaternion];
}

- (void)toSwitch:(UIButton*)button {
    _switchButton.selected = _switchButton.selected ? false : true;
}

- (void)makeDistanceFrom:(GLKQuaternion)from to:(GLKQuaternion)to
{
    if(_progress > 0.999999) {
        self.view.userInteractionEnabled = YES;
        return;
    }
    
    //四元数插值
    _progress += 0.05;
    _progress = MIN(_progress, 1);
    GLKQuaternion rotationE = GLKQuaternionNormalize(GLKQuaternionSlerp(from, to, _progress));
    
    NSArray* rotations = [AAPLOpenGLRenderer allRotationsWithQuaternion:rotationE];
    float roll  = [[rotations objectAtIndex:0] floatValue];
    float pitch = [[rotations objectAtIndex:1] floatValue];
    float yaw   = [[rotations objectAtIndex:2] floatValue];
    NSString * label = [_openGLRenderer resetRoll:roll yaw:yaw pitch:pitch];
    _degreeLabel.text = label;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [self makeDistanceFrom:rotationE to:to];
    });
}
@end
