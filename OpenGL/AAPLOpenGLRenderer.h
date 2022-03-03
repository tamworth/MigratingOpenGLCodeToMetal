/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for the renderer class that performs OpenGL state setup and per-frame rendering.
*/

#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include "AAPLGLHeaders.h"
#import <GLKit/GLKTextureLoader.h>
@import GLKit.GLKMath;

static const CGSize AAPLInteropTextureSize = {1024, 1024};

@interface AAPLOpenGLRenderer : NSObject
@property (atomic, assign) float rotationX;
@property (atomic, assign) float rotationY;
@property (atomic, assign) float rotationZ;
- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName;

- (void)draw;

- (void)resize:(CGSize)size;

- (NSArray*)allRotations;
- (NSString*)resetRotation;
- (NSString*)resetDeltaRotation;

- (NSString*)resetRoll:(float)roll
              yaw:(float)yaw
            pitch:(float)pitch;
- (NSString*)rotateWithRadianX:(float)x
              withRadianY:(float)y
              withRadianZ:(float)z;


- (NSString*)rotateDeltaWithRadianX:(float)x
              withRadianY:(float)y
                        withRadianZ:(float)z;
- (NSString*)resetDeltaRoll:(float)roll
              yaw:(float)yaw
                      pitch:(float)pitch;


+ (NSArray*)allRotationsWithQuaternion:(GLKQuaternion)quaternion;
+ (GLKQuaternion)quaternionWithRoll:(float)roll
                                yaw:(float)yaw
                              pitch:(float)pitch;
@end
