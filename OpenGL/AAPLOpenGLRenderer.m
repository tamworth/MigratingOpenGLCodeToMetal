/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of the renderer class that performs OpenGL state setup and per-frame rendering.
*/

#import "AAPLOpenGLRenderer.h"
#import "AAPLMathUtilities.h"
#import "AAPLMeshData.h"
#import "AAPLCommonDefinitions.h"
#import <Foundation/Foundation.h>
#import <simd/simd.h>
#include <math.h>

typedef struct ksMatrix4
{
    float   m[4][4];
} ksMatrix4;


// result[x][y] = a[x][0]*b[0][y]+a[x][1]*b[1][y]+a[x][2]*b[2][y]+a[x][3]*b[3][y];
void ksMatrixMultiply(ksMatrix4 * result, const ksMatrix4 *a, const ksMatrix4 *b)
{
    ksMatrix4 tmp;
    int i;

    for (i = 0; i < 4; i++)
    {
        tmp.m[i][0] = (a->m[i][0] * b->m[0][0]) +
            (a->m[i][1] * b->m[1][0]) +
            (a->m[i][2] * b->m[2][0]) +
            (a->m[i][3] * b->m[3][0]) ;

        tmp.m[i][1] = (a->m[i][0] * b->m[0][1]) +
            (a->m[i][1] * b->m[1][1]) +
            (a->m[i][2] * b->m[2][1]) +
            (a->m[i][3] * b->m[3][1]) ;

        tmp.m[i][2] = (a->m[i][0] * b->m[0][2]) +
            (a->m[i][1] * b->m[1][2]) +
            (a->m[i][2] * b->m[2][2]) +
            (a->m[i][3] * b->m[3][2]) ;

        tmp.m[i][3] = (a->m[i][0] * b->m[0][3]) +
            (a->m[i][1] * b->m[1][3]) +
            (a->m[i][2] * b->m[2][3]) +
            (a->m[i][3] * b->m[3][3]) ;
    }

    memcpy(result, &tmp, sizeof(ksMatrix4));
}

void ksMatrixRotate(ksMatrix4 * result, float angle, float x, float y, float z)
{
    float sinAngle, cosAngle;
    float mag = sqrtf(x * x + y * y + z * z);

    sinAngle = sinf ( angle * M_PI / 180.0f );
    cosAngle = cosf ( angle * M_PI / 180.0f );
    if ( mag > 0.0f )
    {
        float xx, yy, zz, xy, yz, zx, xs, ys, zs;
        float oneMinusCos;
        ksMatrix4 rotMat;

        x /= mag;
        y /= mag;
        z /= mag;

        xx = x * x;
        yy = y * y;
        zz = z * z;
        xy = x * y;
        yz = y * z;
        zx = z * x;
        xs = x * sinAngle;
        ys = y * sinAngle;
        zs = z * sinAngle;
        oneMinusCos = 1.0f - cosAngle;

        rotMat.m[0][0] = (oneMinusCos * xx) + cosAngle;
        rotMat.m[0][1] = (oneMinusCos * xy) - zs;
        rotMat.m[0][2] = (oneMinusCos * zx) + ys;
        rotMat.m[0][3] = 0.0F;

        rotMat.m[1][0] = (oneMinusCos * xy) + zs;
        rotMat.m[1][1] = (oneMinusCos * yy) + cosAngle;
        rotMat.m[1][2] = (oneMinusCos * yz) - xs;
        rotMat.m[1][3] = 0.0F;

        rotMat.m[2][0] = (oneMinusCos * zx) - ys;
        rotMat.m[2][1] = (oneMinusCos * yz) + xs;
        rotMat.m[2][2] = (oneMinusCos * zz) + cosAngle;
        rotMat.m[2][3] = 0.0F;

        rotMat.m[3][0] = 0.0F;
        rotMat.m[3][1] = 0.0F;
        rotMat.m[3][2] = 0.0F;
        rotMat.m[3][3] = 1.0F;

        ksMatrixMultiply( result, &rotMat, result );
    }
}

@implementation AAPLOpenGLRenderer
{
    GLuint _defaultFBOName;
    CGSize _viewSize;

    GLint _mvpUniformIndex;
    GLint _uniformBufferIndex;

    matrix_float4x4 _projectionMatrix;
    // Open GL Objects you use to render the temple mesh.
    GLuint _templeVAO;
    GLuint _templeVertexPositions;
    GLuint _templeVertexGenerics;
    GLuint _templeProgram;
    GLuint _templeMVPUniformLocation;
    matrix_float4x4 _templeCameraMVPMatrix;

    // Arrays of submesh index buffers and textures for temple mesh.
    NSUInteger _numTempleSubmeshes;
    GLuint *_templeIndexBufferCounts;
    GLuint *_templeIndexBuffers;
    GLuint *_templeTextures;

#if RENDER_REFLECTION
    GLuint _reflectionFBO;
    GLuint _reflectionColorTexture;
    GLuint _reflectionDepthBuffer;
    GLuint _reflectionQuadBuffer;
    GLuint _reflectionQuadVAO;
    GLuint _reflectionProgram;
    GLuint _reflectionQuadMVPUniformLocation;

    matrix_float4x4 _reflectionQuadMVPMatrix;
    matrix_float4x4 _templeReflectionMVPMatrix;
#endif


#if USE_UNIFORM_BLOCKS
    // Uniform buffer instance variables.
    GLuint _uniformBlockIndex;
    GLuint _uniformBlockBuffer;
    GLint *_uniformBlockOffsets;
    GLubyte *_uniformBlockData;
    GLsizei _uniformBlockSize;
#else
    GLuint _templeNormalMatrixUniformLocation;
    GLuint _ambientLightColorUniformLocation;
    GLuint _directionalLightInvDirectionUniformLocation;
    GLuint _directionalLightColorUniformLocation;

    matrix_float3x3 _templeNormalMatrix;
    vector_float3 _ambientLightColor;
    vector_float3 _directionalLightInvDirection;
    vector_float3 _directionalLightColor;
#endif
    
    GLKQuaternion _rotationE;
    GLKQuaternion _rotationDeltaE;
}

- (instancetype)initWithDefaultFBOName:(GLuint)defaultFBOName
{
    self = [super init];
    if(self)
    {
        NSLog(@"%s %s", glGetString(GL_RENDERER), glGetString(GL_VERSION));

        // Build all of your objects and setup initial state here.
        _defaultFBOName = defaultFBOName;
        [self buildTempleObjects];

        [self buildReflectiveQuadObjects];
        
        [self resetRotation];
        [self resetDeltaRotation];
    }

    return self;
}

- (void) dealloc
{
    glDeleteProgram(_reflectionProgram);
    glDeleteProgram(_templeProgram);

    glDeleteVertexArrays(1, &_templeVAO);
    glDeleteVertexArrays(1, &_reflectionQuadVAO);

    glDeleteBuffers(1, &_templeVertexPositions);
    glDeleteBuffers(1, &_templeVertexGenerics);
    glDeleteBuffers(1, &_reflectionQuadBuffer);

    glDeleteTextures(1, &_reflectionColorTexture);
    glDeleteRenderbuffers(1, &_reflectionDepthBuffer);

    glDeleteFramebuffers(1, &_reflectionFBO);

    for(int i = 0; i < _numTempleSubmeshes; i++)
    {
        glDeleteTextures(1, &_templeTextures[i]);
        glDeleteBuffers(1, &_templeIndexBuffers[i]);
    }

    free(_templeIndexBufferCounts);
    free(_templeIndexBuffers);
    free(_templeTextures);
}

- (void) buildTempleObjects
{
    // Load the mesh data from a file.
    NSError *error;

    NSURL *modelFileURL = [[NSBundle mainBundle] URLForResource:@"Meshes/Temple.obj"
                                                  withExtension:nil];

    NSAssert(modelFileURL, @"Could not find model (%@) file in the bundle.", modelFileURL.absoluteString);

    // Load mesh data from a file into memory.
    // This only loads data from the bundle and does not create any OpenGL objects.

    AAPLMeshData *meshData = [[AAPLMeshData alloc] initWithURL:modelFileURL error:&error];

    NSAssert(meshData, @"Could not load mesh from model file (%@), error: %@.", modelFileURL.absoluteString, error);

    // Extract the vertex data, reconfigure the layout for the vertex shader, and place the data into
    // an OpenGL vertex buffer.
    {
        NSUInteger positionElementSize = sizeof(vector_float3);
        NSUInteger positionDataSize    = positionElementSize * meshData.vertexCount;

        NSUInteger genericElementSize = sizeof(AAPLVertexGenericData);
        NSUInteger genericsDataSize   = genericElementSize * meshData.vertexCount;

        vector_float3         *positionsArray = (vector_float3 *)malloc(positionDataSize);
        AAPLVertexGenericData *genericsArray = (AAPLVertexGenericData *)malloc(genericsDataSize);

        // Extract vertex data from the buffer and lay it out for OpenGL buffers.
        struct AAPLVertexData *vertexData = meshData.vertexData;

        for(unsigned long vertex = 0; vertex < meshData.vertexCount; vertex++)
        {
            positionsArray[vertex] = vertexData[vertex].position;
            genericsArray[vertex].texcoord = vertexData[vertex].texcoord;
            genericsArray[vertex].normal.x = vertexData[vertex].normal.x;
            genericsArray[vertex].normal.y = vertexData[vertex].normal.y;
            genericsArray[vertex].normal.z = vertexData[vertex].normal.z;
        }

        // Place formatted vertex data into OpenGL buffers.
        glGenBuffers(1, &_templeVertexPositions);

        glBindBuffer(GL_ARRAY_BUFFER, _templeVertexPositions);

        glBufferData(GL_ARRAY_BUFFER, positionDataSize, positionsArray, GL_STATIC_DRAW);

        glGenBuffers(1, &_templeVertexGenerics);

        glBindBuffer(GL_ARRAY_BUFFER, _templeVertexGenerics);

        glBufferData(GL_ARRAY_BUFFER, genericsDataSize, genericsArray, GL_STATIC_DRAW);

        glGenVertexArrays(1, &_templeVAO);

        glBindVertexArray(_templeVAO);

        // Setup buffer with positions.
        glBindBuffer(GL_ARRAY_BUFFER, _templeVertexPositions);
        glVertexAttribPointer(AAPLVertexAttributePosition, 3, GL_FLOAT, GL_FALSE, sizeof(vector_float3), BUFFER_OFFSET(0));
        glEnableVertexAttribArray(AAPLVertexAttributePosition);

        // Setup buffer with normals and texture coordinates.
        glBindBuffer(GL_ARRAY_BUFFER, _templeVertexGenerics);

        glVertexAttribPointer(AAPLVertexAttributeTexcoord, 2, GL_FLOAT, GL_FALSE, sizeof(AAPLVertexGenericData), BUFFER_OFFSET(0));
        glEnableVertexAttribArray(AAPLVertexAttributeTexcoord);

        glVertexAttribPointer(AAPLVertexAttributeNormal, 3, GL_FLOAT, GL_FALSE, sizeof(AAPLVertexGenericData), BUFFER_OFFSET(sizeof(vector_float2)));
        glEnableVertexAttribArray(AAPLVertexAttributeNormal);
    }

    // Load submesh data into index buffers and textures.
    {
        _numTempleSubmeshes = (NSUInteger)meshData.submeshes.allValues.count;
        _templeIndexBuffers = (GLuint*)malloc(sizeof(GLuint*) * _numTempleSubmeshes);
        _templeIndexBufferCounts = (GLuint*)malloc(sizeof(GLuint*) * _numTempleSubmeshes);
        _templeTextures = (GLuint*)malloc(sizeof(GLuint*) * _numTempleSubmeshes);

        NSDictionary *loaderOptions =
        @{
          GLKTextureLoaderGenerateMipmaps : @YES,
          GLKTextureLoaderOriginBottomLeft : @YES,
          };

        for(NSUInteger index = 0; index < _numTempleSubmeshes; index++)
        {
            AAPLSubmeshData *submeshData = meshData.submeshes.allValues[index];

            _templeIndexBufferCounts[index] = (GLuint)submeshData.indexCount;

            NSUInteger indexBufferSize = sizeof(uint32_t) * submeshData.indexCount;

            GLuint indexBufferName;

            glGenBuffers(1, &indexBufferName);

            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBufferName);

            glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexBufferSize, submeshData.indexData, GL_STATIC_DRAW);

            _templeIndexBuffers[index] = indexBufferName;

            GLKTextureInfo *texInfo = [GLKTextureLoader textureWithContentsOfURL:submeshData.baseColorMapURL
                                                                         options:loaderOptions
                                                                           error:&error];

            NSAssert(texInfo, @"Could not load image (%@) into OpenGL texture, error: %@.",
                     submeshData.baseColorMapURL.absoluteString, error);

            _templeTextures[index] = texInfo.name;
        }
    }

    // Create program object and setup for uniforms.
    {
        NSURL *vertexSourceURL = [[NSBundle mainBundle] URLForResource:@"temple" withExtension:@"vsh"];
        NSURL *fragmentSourceURL = [[NSBundle mainBundle] URLForResource:@"temple" withExtension:@"fsh"];

        _templeProgram = [AAPLOpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                                       withFragmentSourceURL:fragmentSourceURL
                                                                  hasNormals:YES];

        _templeMVPUniformLocation = glGetUniformLocation(_templeProgram, "modelViewProjectionMatrix");

        GLint location = -1;
        location = glGetUniformLocation(_templeProgram, "templeNormalMatrix");
        NSAssert(location >= 0, @"No location for `templeNormalMatrix`.");
        _templeNormalMatrixUniformLocation = (GLuint)location;


        location = glGetUniformLocation(_templeProgram, "ambientLightColor");
        NSAssert(location >= 0, @"No location for `ambientLightColor`.");
        _ambientLightColorUniformLocation = (GLuint)location;

        location = glGetUniformLocation(_templeProgram, "directionalLightInvDirection");
        NSAssert(location >= 0, @"No location for `directionalLightInvDirection`.");
        _directionalLightInvDirectionUniformLocation = (GLuint)location;

        location = glGetUniformLocation(_templeProgram, "directionalLightColor");
        NSAssert(location >= 0, @"No location for `directionalLightColor`.");
        _directionalLightColorUniformLocation = location;

        _templeMVPUniformLocation = glGetUniformLocation(_templeProgram, "modelViewProjectionMatrix");
    }
}

- (void) buildReflectiveQuadObjects
{
#if RENDER_REFLECTION
    // Setup vertex buffers and array object for the reflective quad.
    {
        static const AAPLQuadVertex AAPLQuadVertices[] =
        {
            { { -500, -500, 0.0, 1.0}, {1.0, 0.0} },
            { { -500,  500, 0.0, 1.0}, {1.0, 1.0} },
            { {  500,  500, 0.0, 1.0}, {0.0, 1.0} },

            { { -500, -500, 0.0, 1.0}, {1.0, 0.0} },
            { {  500,  500, 0.0, 1.0}, {0.0, 1.0} },
            { {  500, -500, 0.0, 1.0}, {0.0, 0.0} },
        };

        glGenBuffers(1, &_reflectionQuadBuffer);

        glBindBuffer(GL_ARRAY_BUFFER, _reflectionQuadBuffer);

        glBufferData(GL_ARRAY_BUFFER, sizeof(AAPLQuadVertices), AAPLQuadVertices, GL_STATIC_DRAW);

        glGenVertexArrays(1, &_reflectionQuadVAO);

        glBindVertexArray(_reflectionQuadVAO);

        glBindBuffer(GL_ARRAY_BUFFER, _reflectionQuadBuffer);

        glVertexAttribPointer(AAPLVertexAttributePosition, 4, GL_FLOAT, GL_FALSE,
                              sizeof(AAPLQuadVertex), BUFFER_OFFSET(0));
        glEnableVertexAttribArray(AAPLVertexAttributePosition);

        glVertexAttribPointer(AAPLVertexAttributeTexcoord, 2, GL_FLOAT, GL_FALSE,
                              sizeof(AAPLQuadVertex), BUFFER_OFFSET(offsetof(AAPLQuadVertex, texcoord)));
        glEnableVertexAttribArray(AAPLVertexAttributeTexcoord);

        GetGLError();
    }

    // Create texture and framebuffer objects to render and display the reflection.
    {
        // Create a texture object that you apply to the model.
        glGenTextures(1, &_reflectionColorTexture);
        glBindTexture(GL_TEXTURE_2D, _reflectionColorTexture);

        // Set up filter and wrap modes for the texture object.
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        // Mipmap generation is not accelerated on iOS, so you can't enable trilinear filtering.
#if TARGET_IOS
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
#else
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
#endif

        // Allocate a texture image to which you can render to. Pass `NULL` for the data parameter
        // becuase you don't need to load image data. You generate the image by rendering to the texture.
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA,
                     AAPLReflectionSize.x, AAPLReflectionSize.y, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, NULL);

        glGenRenderbuffers(1, &_reflectionDepthBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _reflectionDepthBuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24,
                              AAPLReflectionSize.x, AAPLReflectionSize.y);

        glGenFramebuffers(1, &_reflectionFBO);
        glBindFramebuffer(GL_FRAMEBUFFER, _reflectionFBO);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _reflectionColorTexture , 0);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _reflectionDepthBuffer);

        NSAssert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE,
                 @"Failed to make complete framebuffer object %x.", glCheckFramebufferStatus(GL_FRAMEBUFFER));

        GetGLError();
    }

    // Build the program object used to render the reflective quad.
    {
        NSURL *vertexSourceURL = [[NSBundle mainBundle] URLForResource:@"reflect" withExtension:@"vsh"];
        NSURL *fragmentSourceURL = [[NSBundle mainBundle] URLForResource:@"reflect" withExtension:@"fsh"];

        _reflectionProgram = [AAPLOpenGLRenderer buildProgramWithVertexSourceURL:vertexSourceURL
                                                          withFragmentSourceURL:fragmentSourceURL
                                                                      hasNormals:NO];

        _reflectionQuadMVPUniformLocation = glGetUniformLocation(_reflectionProgram, "modelViewProjectionMatrix");
    }
#endif
}

- (NSString*)resetDeltaRotation {
    _rotationDeltaE = GLKQuaternionIdentity;
    return [self rotateDeltaWithRadianX:0.00001 withRadianY:0 withRadianZ:0];
}

- (NSString*)resetRotation {
    _rotationE = GLKQuaternionIdentity;
    return [self rotateWithRadianX:0.00001 withRadianY:0 withRadianZ:0];
}

/// <#Description#>
/// @param x 从左到右，由小到大
/// @param y 由下到上 由小到大
/// @param z 顺时针 由小到大
- (NSString*)rotateWithRadianX:(float)x
              withRadianY:(float)y
              withRadianZ:(float)z
{
    GLKVector3 up = GLKVector3Make(0.0f, 1.0f, 0.0f);
    GLKVector3 right = GLKVector3Make(1.0f, 0.0f, 0.0f);
    GLKVector3 front = GLKVector3Make(0.0f, 0.0f, -1.0f);
    up = GLKQuaternionRotateVector3(GLKQuaternionInvert(_rotationE), up);
    _rotationE = GLKQuaternionMultiply(_rotationE, GLKQuaternionMakeWithAngleAndVector3Axis(-x, up));
    right = GLKQuaternionRotateVector3(GLKQuaternionInvert(_rotationE), right);
    _rotationE = GLKQuaternionMultiply(_rotationE, GLKQuaternionMakeWithAngleAndVector3Axis(-y, right));
    front = GLKQuaternionRotateVector3(GLKQuaternionInvert(_rotationE), front);
    _rotationE = GLKQuaternionMultiply(_rotationE, GLKQuaternionMakeWithAngleAndVector3Axis(z, front));
    
    CGFloat roll  = atan2(2 * (_rotationE.w * _rotationE.z + _rotationE.x * _rotationE.y) , 1 - 2 * (_rotationE.z * _rotationE.z + _rotationE.x * _rotationE.x));
    CGFloat pitch = asin(simd_clamp(2 * (_rotationE.w * _rotationE.x - _rotationE.y * _rotationE.z) , -1.0f , 1.0f));
    CGFloat yaw   = atan2(2 * (_rotationE.w * _rotationE.y + _rotationE.z * _rotationE.x) , 1 - 2 * (_rotationE.x * _rotationE.x + _rotationE.y * _rotationE.y));
    NSString* str = [NSString stringWithFormat:@"x: %.2f  y:%.2f  z:%.2f", -pitch * 360 / M_PI, -yaw * 360 / M_PI, roll * 360 / M_PI];
    return str;
}

- (NSString*)rotateDeltaWithRadianX:(float)x
              withRadianY:(float)y
              withRadianZ:(float)z
{
    GLKVector3 up = GLKVector3Make(0.0f, 1.0f, 0.0f);
    GLKVector3 right = GLKVector3Make(1.0f, 0.0f, 0.0f);
    GLKVector3 front = GLKVector3Make(0.0f, 0.0f, -1.0f);
    up = GLKQuaternionRotateVector3(GLKQuaternionInvert(_rotationDeltaE), up);
    _rotationDeltaE = GLKQuaternionMultiply(_rotationDeltaE, GLKQuaternionMakeWithAngleAndVector3Axis(-x, up));
    right = GLKQuaternionRotateVector3(GLKQuaternionInvert(_rotationDeltaE), right);
    _rotationDeltaE = GLKQuaternionMultiply(_rotationDeltaE, GLKQuaternionMakeWithAngleAndVector3Axis(-y, right));
    front = GLKQuaternionRotateVector3(GLKQuaternionInvert(_rotationDeltaE), front);
    _rotationDeltaE = GLKQuaternionMultiply(_rotationDeltaE, GLKQuaternionMakeWithAngleAndVector3Axis(z, front));
    
    CGFloat roll  = atan2(2 * (_rotationDeltaE.w * _rotationDeltaE.z + _rotationDeltaE.x * _rotationDeltaE.y) , 1 - 2 * (_rotationDeltaE.z * _rotationDeltaE.z + _rotationDeltaE.x * _rotationDeltaE.x));
    CGFloat pitch = asin(simd_clamp(2 * (_rotationDeltaE.w * _rotationDeltaE.x - _rotationDeltaE.y * _rotationDeltaE.z) , -1.0f , 1.0f));
    CGFloat yaw   = atan2(2 * (_rotationDeltaE.w * _rotationDeltaE.y + _rotationDeltaE.z * _rotationDeltaE.x) , 1 - 2 * (_rotationDeltaE.x * _rotationDeltaE.x + _rotationDeltaE.y * _rotationDeltaE.y));
    NSString* str = [NSString stringWithFormat:@"x: %.2f  y:%.2f  z:%.2f", -pitch * 360 / M_PI, -yaw * 360 / M_PI, roll * 360 / M_PI];
    return str;
}

- (NSString*)resetRoll:(float)roll
              yaw:(float)yaw
            pitch:(float)pitch
{
    _rotationE = [AAPLOpenGLRenderer quaternionWithRoll:roll yaw:yaw pitch:pitch];
    
    
    CGFloat roll1  = atan2(2 * (_rotationE.w * _rotationE.z + _rotationE.x * _rotationE.y) , 1 - 2 * (_rotationE.z * _rotationE.z + _rotationE.x * _rotationE.x));
    CGFloat pitch1 = asin(simd_clamp(2 * (_rotationE.w * _rotationE.x - _rotationE.y * _rotationE.z) , -1.0f , 1.0f));
    CGFloat yaw1   = atan2(2 * (_rotationE.w * _rotationE.y + _rotationE.z * _rotationE.x) , 1 - 2 * (_rotationE.x * _rotationE.x + _rotationE.y * _rotationE.y));
    NSString* str = [NSString stringWithFormat:@"x: %.2f y:%.2f z:%.2f", -pitch1 * 360 / M_PI, -yaw1 * 360 / M_PI, roll1 * 360 / M_PI];
    return str;
}


- (NSString*)resetDeltaRoll:(float)roll
              yaw:(float)yaw
            pitch:(float)pitch
{
    _rotationDeltaE = [AAPLOpenGLRenderer quaternionWithRoll:roll yaw:yaw pitch:pitch];
    
    
    CGFloat roll1  = atan2(2 * (_rotationDeltaE.w * _rotationDeltaE.z + _rotationDeltaE.x * _rotationDeltaE.y) , 1 - 2 * (_rotationDeltaE.z * _rotationDeltaE.z + _rotationDeltaE.x * _rotationDeltaE.x));
    CGFloat pitch1 = asin(simd_clamp(2 * (_rotationDeltaE.w * _rotationDeltaE.x - _rotationDeltaE.y * _rotationDeltaE.z) , -1.0f , 1.0f));
    CGFloat yaw1   = atan2(2 * (_rotationDeltaE.w * _rotationDeltaE.y + _rotationDeltaE.z * _rotationDeltaE.x) , 1 - 2 * (_rotationDeltaE.x * _rotationDeltaE.x + _rotationDeltaE.y * _rotationDeltaE.y));
    NSString* str = [NSString stringWithFormat:@"x: %.2f y:%.2f z:%.2f", -pitch1 * 360 / M_PI, -yaw1 * 360 / M_PI, roll1 * 360 / M_PI];
    return str;
}

- (NSArray*)allRotations
{
    return [AAPLOpenGLRenderer allRotationsWithQuaternion:_rotationE];
}

- (void)updateFrameState
{
    //外旋z-y-x，内旋x-y-z
    const vector_float3 ambientLightColor = {0.02, 0.02, 0.02};
    const vector_float3 directionalLightDirection = vector_normalize ((vector_float3){0.0, 0.0, 1.0});
    const vector_float3 directionalLightInvDirection = -directionalLightDirection;
    const vector_float3 directionalLightColor = {.7, .7, .7};
    

    const vector_float3   cameraPosition = {0.0, 0.0, -1000.0};
    const matrix_float4x4 cameraViewMatrix  = matrix4x4_translation(-cameraPosition);
#if 1
    // Get Quaternion Rotation
    GLKQuaternion rotationE = _rotationE;
    GLKVector3 rAxis = GLKQuaternionAxis(rotationE);
    float rAngle = GLKQuaternionAngle(rotationE);
    // Set Modelview Matrix
    GLKMatrix4 modelviewMatrix = GLKMatrix4Identity;
    modelviewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -0.55f);
    modelviewMatrix = GLKMatrix4Rotate(modelviewMatrix, rAngle, rAxis.x, rAxis.y, rAxis.z);
    modelviewMatrix = GLKMatrix4Scale(modelviewMatrix, 0.5f, 0.5f, 0.5f);
    matrix_float4x4 templeModelMatrix = (matrix_float4x4){{
        {modelviewMatrix.m00, modelviewMatrix.m01, modelviewMatrix.m02, modelviewMatrix.m03},
        {modelviewMatrix.m10, modelviewMatrix.m11, modelviewMatrix.m12, modelviewMatrix.m13},
        {modelviewMatrix.m20, modelviewMatrix.m21, modelviewMatrix.m22, modelviewMatrix.m23},
        {modelviewMatrix.m30, modelviewMatrix.m31, modelviewMatrix.m32, modelviewMatrix.m33}}};
    
    if(1) {
        GLKQuaternion rotationE = _rotationDeltaE;
        GLKVector3 rAxis = GLKQuaternionAxis(rotationE);
        float rAngle = GLKQuaternionAngle(rotationE);
        // Set Modelview Matrix
//        GLKMatrix4 modelviewMatrix = GLKMatrix4Make(templeModelMatrix.columns[0][0],
//                                                    templeModelMatrix.columns[0][1],
//                                                    templeModelMatrix.columns[0][2],
//                                                    templeModelMatrix.columns[0][3],
//                                                    templeModelMatrix.columns[1][0],
//                                                    templeModelMatrix.columns[1][1],
//                                                    templeModelMatrix.columns[1][2],
//                                                    templeModelMatrix.columns[1][3],
//                                                    templeModelMatrix.columns[2][0],
//                                                    templeModelMatrix.columns[2][1],
//                                                    templeModelMatrix.columns[2][2],
//                                                    templeModelMatrix.columns[2][3],
//                                                    templeModelMatrix.columns[3][0],
//                                                    templeModelMatrix.columns[3][1],
//                                                    templeModelMatrix.columns[3][2],
//                                                    templeModelMatrix.columns[3][3]);
        modelviewMatrix = GLKMatrix4Identity;
//        modelviewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -0.55f);
        modelviewMatrix = GLKMatrix4Rotate(modelviewMatrix, rAngle, rAxis.x, rAxis.y, rAxis.z);
//        modelviewMatrix = GLKMatrix4Scale(modelviewMatrix, 0.5f, 0.5f, 0.5f);
        matrix_float4x4 templeModelMatrix1 = (matrix_float4x4){{
            {modelviewMatrix.m00, modelviewMatrix.m01, modelviewMatrix.m02, modelviewMatrix.m03},
            {modelviewMatrix.m10, modelviewMatrix.m11, modelviewMatrix.m12, modelviewMatrix.m13},
            {modelviewMatrix.m20, modelviewMatrix.m21, modelviewMatrix.m22, modelviewMatrix.m23},
            {modelviewMatrix.m30, modelviewMatrix.m31, modelviewMatrix.m32, modelviewMatrix.m33}}};
        
        
        templeModelMatrix       = matrix_multiply(templeModelMatrix1, templeModelMatrix);
    }
#else
    const vector_float3   templeRotationXAxis      = {1, 0, 0};
    const vector_float3   templeRotationYAxis      = {0, 1, 0};
    const vector_float3   templeRotationZAxis      = {0, 0, 1};
    const matrix_float4x4 templeRotationXMatrix    = matrix4x4_rotation (self.rotationX, templeRotationXAxis);
    const matrix_float4x4 templeRotationYMatrix    = matrix4x4_rotation (self.rotationY, templeRotationYAxis);
    const matrix_float4x4 templeRotationZMatrix    = matrix4x4_rotation (self.rotationZ, templeRotationZAxis);
    matrix_float4x4 templeModelMatrix       = matrix_multiply(templeRotationXMatrix, templeRotationYMatrix);
    templeModelMatrix       = matrix_multiply(templeModelMatrix, templeRotationZMatrix);
#endif
    const matrix_float4x4 templeTranslationMatrix = matrix4x4_translation(0.0, -200, 0);
    templeModelMatrix       = matrix_multiply(templeModelMatrix, templeTranslationMatrix);
    matrix_float4x4 templeModelViewMatrix   = matrix_multiply (cameraViewMatrix, templeModelMatrix);
    
    
    const matrix_float3x3 templeNormalMatrix      = matrix3x3_upper_left(templeModelMatrix);

    _templeNormalMatrix           = templeNormalMatrix;
    _ambientLightColor            = ambientLightColor;
    _directionalLightInvDirection = directionalLightInvDirection;
    _directionalLightColor        = directionalLightColor;

    _templeCameraMVPMatrix        = matrix_multiply(_projectionMatrix, templeModelViewMatrix);

//#if RENDER_REFLECTION
//    const vector_float3  quadRotationAxis  = {1, 0, 0};
//    const float          quadRotationAngle = 270 * M_PI/180;
//    const vector_float3  quadTranslation   = {0, 300, 0};
//
//    const matrix_float4x4 quadRotationMatrix            = matrix4x4_rotation(quadRotationAngle, quadRotationAxis);
//    const matrix_float4x4 quadTranslationMatrtix        = matrix4x4_translation(quadTranslation);
//    const matrix_float4x4 quadModelMatrix               = matrix_multiply(quadTranslationMatrtix, quadRotationMatrix);
//    const matrix_float4x4 quadModeViewMatrix            = matrix_multiply(cameraViewMatrix, quadModelMatrix);
//
//    const vector_float4 target = matrix_multiply(quadModelMatrix, (vector_float4){0, 0, 0, 1});
//    const vector_float4 eye    = matrix_multiply(quadModelMatrix, (vector_float4){0.0, 0.0, 250, 1});
//    const vector_float4 up     = matrix_multiply(quadModelMatrix, (vector_float4){0, 1, 0, 1});
//
//    const matrix_float4x4 reflectionViewMatrix       = matrix_look_at_left_hand(eye.xyz, target.xyz, up.xyz);
//    const matrix_float4x4 reflectionModelViewMatrix  = matrix_multiply(reflectionViewMatrix, templeModelMatrix);
//    const matrix_float4x4 reflectionProjectionMatrix = matrix_perspective_left_hand_gl(M_PI/2.0, 1, 0.1, 3000.0);
//
//    _templeReflectionMVPMatrix = matrix_multiply(reflectionProjectionMatrix, reflectionModelViewMatrix);
//
//    _reflectionQuadMVPMatrix   = matrix_multiply(_projectionMatrix, quadModeViewMatrix);
//#endif
//    self.rotationX += .01;
//    self.rotationY += .01;
//    self.rotationZ += .01;
}

- (void)resize:(CGSize)size
{
    // Handle the resize of the draw rectangle. In particular, update the perspective projection matrix
    // with a new aspect ratio because the view orientation, layout, or size has changed.
    _viewSize = size;
    float aspect = (float)size.width / size.height;
    _projectionMatrix = matrix_perspective_left_hand_gl(65.0f * (M_PI / 180.0f), aspect, 1.0f, 5000.0);
}

- (void)draw
{
    // Set up the model-view and projection matrices.
    [self updateFrameState];

    glUseProgram(_templeProgram);

    float packed3x3NormalMatrix[9] =
    {
        _templeNormalMatrix.columns[0].x,
        _templeNormalMatrix.columns[0].y,
        _templeNormalMatrix.columns[0].z,
        _templeNormalMatrix.columns[1].x,
        _templeNormalMatrix.columns[1].y,
        _templeNormalMatrix.columns[1].z,
        _templeNormalMatrix.columns[2].x,
        _templeNormalMatrix.columns[2].y,
        _templeNormalMatrix.columns[2].z,
    };

    glUniformMatrix3fv(_templeNormalMatrixUniformLocation, 1, GL_FALSE, packed3x3NormalMatrix);

    glUniform3fv(_ambientLightColorUniformLocation, 1, (GLvoid*)&_ambientLightColor);
    glUniform3fv(_directionalLightInvDirectionUniformLocation, 1, (GLvoid*)&_directionalLightInvDirection);
    glUniform3fv(_directionalLightColorUniformLocation, 1, (GLvoid*)&_directionalLightColor);

    glEnable(GL_DEPTH_TEST);

    glFrontFace(GL_CW);

    glCullFace(GL_BACK);

#if RENDER_REFLECTION

    // Bind the reflection FBO and render the scene.

    glBindFramebuffer(GL_FRAMEBUFFER, _reflectionFBO);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glViewport(0, 0, AAPLReflectionSize.x, AAPLReflectionSize.y);
    // Use the program that renders the temple.
    glUseProgram(_templeProgram);

    glUniformMatrix4fv(_templeMVPUniformLocation, 1, GL_FALSE, (const GLfloat*)&_templeReflectionMVPMatrix);

    // Bind the vertex array object with the temple mesh vertices.
    glBindVertexArray(_templeVAO);

    // Draw the temple object to the reflection texture.
    for(GLuint i = 0; i < _numTempleSubmeshes; i++)
    {
        // Bind the texture to be used.
        glBindTexture(GL_TEXTURE_2D, _templeTextures[i]);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _templeIndexBuffers[i]);
        glDrawElements(GL_TRIANGLES, _templeIndexBufferCounts[i], GL_UNSIGNED_INT, 0);
    }
#if !TARGET_IOS
    // Generate mipmaps from the rendered-to base level. Mipmaps reduce shimmering pixels due to
    // better filtering. (iOS does not accelerate this call, so you don't use mipmaps in iOS.)

    glBindTexture(GL_TEXTURE_2D, _reflectionColorTexture);
    glGenerateMipmap(GL_TEXTURE_2D);

#endif

    // Bind the default FBO to render to the screen.
    glBindFramebuffer(GL_FRAMEBUFFER, _defaultFBOName);

    glViewport(0, 0, _viewSize.width, _viewSize.height);

#endif

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Use the program that renders the temple.
    glUseProgram(_templeProgram);

    glUniformMatrix4fv(_templeMVPUniformLocation, 1, GL_FALSE, (const GLfloat*)&_templeCameraMVPMatrix);

    // Bind the vertex array object with the temple mesh vertices.
    glBindVertexArray(_templeVAO);

    // Draw the temple object to the drawable.
    for(GLuint i = 0; i < _numTempleSubmeshes; i++)
    {
        // Bind the texture to be used.
        glBindTexture(GL_TEXTURE_2D, _templeTextures[i]);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _templeIndexBuffers[i]);
        glDrawElements(GL_TRIANGLES, _templeIndexBufferCounts[i], GL_UNSIGNED_INT, 0);
    }
#if RENDER_REFLECTION

    // Use the program that renders the reflective quad.
    glUseProgram(_reflectionProgram);

    glUniformMatrix4fv(_reflectionQuadMVPUniformLocation, 1, GL_FALSE, (const GLfloat*)&_reflectionQuadMVPMatrix);

    // Bind the texture that you previously render to (i.e. the reflection texture).
    glBindTexture(GL_TEXTURE_2D, _reflectionColorTexture);

    // Bind the quad vertex array object.
    glBindVertexArray(_reflectionQuadVAO);

    // Draw the refection plane.
    glDrawArrays(GL_TRIANGLES, 0, 6);

#endif
}

matrix_float4x4 matrix_perspective_left_hand_gl(float fovyRadians, float aspect, float nearZ, float farZ)
{
    float ys = 1 / tanf(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = (farZ + nearZ) / (farZ - nearZ);
    float ws = -(2.f * farZ * nearZ) / (farZ - nearZ);

    return matrix_make_rows(xs,  0,  0,  0,
                             0, ys,  0,  0,
                             0,  0, zs, ws,
                             0,  0,  1,  0);
}

+ (GLuint)buildProgramWithVertexSourceURL:(NSURL*)vertexSourceURL
                    withFragmentSourceURL:(NSURL*)fragmentSourceURL
                               hasNormals:(BOOL)hasNormals
{
    NSError *error;



    NSString *vertSourceString = [[NSString alloc] initWithContentsOfURL:vertexSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(vertSourceString, @"Could not load vertex shader source, error: %@.", error);

    NSString *fragSourceString = [[NSString alloc] initWithContentsOfURL:fragmentSourceURL
                                                                encoding:NSUTF8StringEncoding
                                                                   error:&error];

    NSAssert(fragSourceString, @"Could not load fragment shader source, error: %@.", error);

    // Prepend the #version definition to the vertex and fragment shaders.
    float  glLanguageVersion;

#if TARGET_IOS
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "OpenGL ES GLSL ES %f", &glLanguageVersion);
#else
    sscanf((char *)glGetString(GL_SHADING_LANGUAGE_VERSION), "%f", &glLanguageVersion);
#endif

    // `GL_SHADING_LANGUAGE_VERSION` returns the standard version form with decimals, but the
    //  GLSL version preprocessor directive simply uses integers (e.g. 1.10 should be 110 and 1.40
    //  should be 140). You multiply the floating point number by 100 to get a proper version number
    //  for the GLSL preprocessor directive.
    GLuint version = 100 * glLanguageVersion;

    NSString *versionString = [[NSString alloc] initWithFormat:@"#version %d", version];

    vertSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, vertSourceString];
    fragSourceString = [[NSString alloc] initWithFormat:@"%@\n%@", versionString, fragSourceString];

    GLuint prgName;

    GLint logLength, status;

    // Create a program object.
    prgName = glCreateProgram();
    glBindAttribLocation(prgName, AAPLVertexAttributePosition, "inPosition");
    glBindAttribLocation(prgName, AAPLVertexAttributeTexcoord, "inTexcoord");

    if(hasNormals)
    {
        glBindAttribLocation(prgName, AAPLVertexAttributeNormal, "inNormal");
    }

    /*
     * Specify and compile a vertex shader.
     */

    GLchar *vertexSourceCString = (GLchar*)vertSourceString.UTF8String;
    GLuint vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, (const GLchar **)&(vertexSourceCString), NULL);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_INFO_LOG_LENGTH, &logLength);

    if (logLength > 0)
    {
        GLchar *log = (GLchar*) malloc(logLength);
        glGetShaderInfoLog(vertexShader, logLength, &logLength, log);
        NSLog(@"Vertex shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the vertex shader:\n%s.\n", vertexSourceCString);

    // Attach the vertex shader to the program.
    glAttachShader(prgName, vertexShader);

    // Delete the vertex shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(vertexShader);

    /*
     * Specify and compile a fragment shader.
     */

    GLchar *fragSourceCString =  (GLchar*)fragSourceString.UTF8String;
    GLuint fragShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragShader, 1, (const GLchar **)&(fragSourceCString), NULL);
    glCompileShader(fragShader);
    glGetShaderiv(fragShader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetShaderInfoLog(fragShader, logLength, &logLength, log);
        NSLog(@"Fragment shader compile log:\n%s.\n", log);
        free(log);
    }

    glGetShaderiv(fragShader, GL_COMPILE_STATUS, &status);

    NSAssert(status, @"Failed to compile the fragment shader:\n%s.", fragSourceCString);

    // Attach the fragment shader to the program.
    glAttachShader(prgName, fragShader);

    // Delete the fragment shader because it's now attached to the program, which retains
    // a reference to it.
    glDeleteShader(fragShader);

    /*
     * Link the program.
     */

    glLinkProgram(prgName);
    glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetProgramInfoLog(prgName, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s.\n", log);
        free(log);
    }

    glGetProgramiv(prgName, GL_LINK_STATUS, &status);

    NSAssert(status, @"Failed to link program.");

    glGetProgramiv(prgName, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar*)malloc(logLength);
        glGetProgramInfoLog(prgName, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s.\n", log);
        free(log);
    }

    GLint samplerLoc = glGetUniformLocation(prgName, "baseColorMap");

    NSAssert(samplerLoc >= 0, @"No uniform location found from `baseColorMap`.");

    glUseProgram(prgName);

    // Indicate that the diffuse texture will be bound to texture unit 0.
    glUniform1i(samplerLoc, AAPLTextureIndexBaseColor);

    GetGLError();

    return prgName;
}

//角度转四元数
+ (GLKQuaternion)quaternionWithRoll:(float)roll
                                yaw:(float)yaw
                              pitch:(float)pitch
{
    float fCosHRoll = cos(roll * .5f);
    float fSinHRoll = sin(roll * .5f);
    float fCosHPitch = cos(pitch * .5f);
    float fSinHPitch = sin(pitch * .5f);
    float fCosHYaw = cos(yaw * .5f);
    float fSinHYaw = sin(yaw * .5f);
  
    /// Cartesian coordinate System
    //w = fCosHRoll * fCosHPitch * fCosHYaw + fSinHRoll * fSinHPitch * fSinHYaw;
    //x = fSinHRoll * fCosHPitch * fCosHYaw - fCosHRoll * fSinHPitch * fSinHYaw;
    //y = fCosHRoll * fSinHPitch * fCosHYaw + fSinHRoll * fCosHPitch * fSinHYaw;
    //z = fCosHRoll * fCosHPitch * fSinHYaw - fSinHRoll * fSinHPitch * fCosHYaw;
  
    float w = fCosHRoll * fCosHPitch * fCosHYaw + fSinHRoll * fSinHPitch * fSinHYaw;
    float x = fCosHRoll * fSinHPitch * fCosHYaw + fSinHRoll * fCosHPitch * fSinHYaw;
    float y = fCosHRoll * fCosHPitch * fSinHYaw - fSinHRoll * fSinHPitch * fCosHYaw;
    float z = fSinHRoll * fCosHPitch * fCosHYaw - fCosHRoll * fSinHPitch * fSinHYaw;
    GLKQuaternion rotationE = GLKQuaternionMake(x, y, z, w);
    
    return rotationE;
}

//四元数转角度
+ (NSArray*)allRotationsWithQuaternion:(GLKQuaternion)quaternion
{
    CGFloat roll  = atan2(2 * (quaternion.w * quaternion.z + quaternion.x * quaternion.y),
                          1 - 2 * (quaternion.z * quaternion.z + quaternion.x * quaternion.x));
    CGFloat pitch = asin(simd_clamp(2 * (quaternion.w * quaternion.x - quaternion.y * quaternion.z) , -1.0f , 1.0f));
    CGFloat yaw   = atan2(2 * (quaternion.w * quaternion.y + quaternion.z * quaternion.x),
                          1 - 2 * (quaternion.x * quaternion.x + quaternion.y * quaternion.y));
//    NSLog(@"radian: %f, %f, %f", -yaw * 360 / M_PI, -pitch * 360 / M_PI, roll * 360 / M_PI);
    
    return @[@(roll), @(pitch), @(yaw)];
}
@end
