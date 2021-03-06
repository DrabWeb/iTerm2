#import "iTermBackgroundImageRenderer.h"

#import "iTermAdvancedSettingsModel.h"
#import "iTermShaderTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface iTermBackgroundImageRendererTransientState ()
@property (nonatomic, strong) id<MTLTexture> texture;
@property (nonatomic) BOOL tiled;
@end

@implementation iTermBackgroundImageRendererTransientState

- (BOOL)skipRenderer {
    return _texture == nil;
}

- (void)writeDebugInfoToFolder:(NSURL *)folder {
    [super writeDebugInfoToFolder:folder];
    [[NSString stringWithFormat:@"tiled=%@", _tiled ? @"YES" : @"NO"] writeToURL:[folder URLByAppendingPathComponent:@"state.txt"]
                                                                      atomically:NO
                                                                        encoding:NSUTF8StringEncoding
                                                                           error:NULL];
}

@end

@implementation iTermBackgroundImageRenderer {
    iTermMetalRenderer *_metalRenderer;

    BOOL _tiled;
    NSImage *_image;
    id<MTLTexture> _texture;
}

- (nullable instancetype)initWithDevice:(id<MTLDevice>)device {
    self = [super init];
    if (self) {
        _metalRenderer = [[iTermMetalRenderer alloc] initWithDevice:device
                                                 vertexFunctionName:@"iTermBackgroundImageVertexShader"
                                               fragmentFunctionName:@"iTermBackgroundImageFragmentShader"
                                                           blending:nil
                                                transientStateClass:[iTermBackgroundImageRendererTransientState class]];
    }
    return self;
}

- (BOOL)rendererDisabled {
    return NO;
}

- (iTermMetalFrameDataStat)createTransientStateStat {
    return iTermMetalFrameDataStatPqCreateBackgroundImageTS;
}

- (void)setImage:(NSImage *)image tiled:(BOOL)tiled context:(nullable iTermMetalBufferPoolContext *)context {
    if (image != _image) {
        _texture = image ? [_metalRenderer textureFromImage:image context:context] : nil;
    }
    _image = image;
    _tiled = tiled;
}

- (void)drawWithFrameData:(nonnull iTermMetalFrameData *)frameData
           transientState:(nonnull __kindof iTermMetalRendererTransientState *)transientState {
    iTermBackgroundImageRendererTransientState *tState = transientState;
    [_metalRenderer drawWithTransientState:tState
                             renderEncoder:frameData.renderEncoder
                          numberOfVertices:6
                              numberOfPIUs:0
                             vertexBuffers:@{ @(iTermVertexInputIndexVertices): tState.vertexBuffer }
                           fragmentBuffers:@{}
                                  textures:@{ @(iTermTextureIndexPrimary): tState.texture }];
}

- (__kindof iTermMetalRendererTransientState * _Nonnull)createTransientStateForConfiguration:(iTermRenderConfiguration *)configuration
                               commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    if (_image == nil) {
        return nil;
    }
    iTermBackgroundImageRendererTransientState * _Nonnull tState =
        [_metalRenderer createTransientStateForConfiguration:configuration
                                               commandBuffer:commandBuffer];

    [self initializeTransientState:tState];

    return tState;
}

- (void)initializeTransientState:(iTermBackgroundImageRendererTransientState *)tState {
    tState.texture = _texture;
    tState.tiled = _tiled;

    const CGFloat scale = tState.configuration.scale;
    const CGSize nativeTextureSize = NSMakeSize(_image.size.width * scale,
                                                _image.size.height * scale);
    const CGSize size = CGSizeMake(tState.configuration.viewportSize.x,
                                   tState.configuration.viewportSize.y);
    CGSize textureSize;
    if (_tiled) {
        textureSize = CGSizeMake(size.width / nativeTextureSize.width,
                                 size.height / nativeTextureSize.height);
    } else {
        textureSize = CGSizeMake(1, 1);
    }
    const CGFloat topMargin = [iTermAdvancedSettingsModel terminalVMargin] * scale;
    const CGFloat bottomMargin = topMargin;
    tState.vertexBuffer = [_metalRenderer newQuadWithFrame:CGRectMake(0,
                                                                      -topMargin,
                                                                      size.width,
                                                                      size.height + topMargin + bottomMargin)
                                              textureFrame:CGRectMake(0,
                                                                      0,
                                                                      textureSize.width,
                                                                      textureSize.height)
                                               poolContext:tState.poolContext];
}

@end

NS_ASSUME_NONNULL_END
